import XCTest

/// 見本データの状態。アプリの `-sampleData` に渡す名前と同じ。
enum Scenario: String {
    /// 今日の分が残っていて、ロックされている。
    case locked
    /// 目標の今日の分は終えたが、タスクの着手リミットを過ぎて、ロックされている。
    case taskLocked
    /// ロックはまだだが、今日のうちに次のロックが来る。
    case countdown
    /// 今日の分をすべて終えて、自由。
    case free
    /// 何も登録していない。初回設定から始まる。
    case fresh
}

/// 画面の言語。確認は識別子で行うので、どちらの言語でも同じテストが通る。
enum Language {
    case english
    case japanese

    var launchArguments: [String] {
        switch self {
        case .english: ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        case .japanese: ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        }
    }

    /// 画面の写しの名前に付ける印。
    var suffix: String {
        switch self {
        case .english: ""
        case .japanese: "-ja"
        }
    }
}

/// 下のタブ。並び順は画面と同じ。
enum AppTab: Int {
    case today, plan, insights

    /// アプリの `-sampleTab` に渡す名前。「今日」は初期値なので渡さない。
    var launchArgument: String? {
        switch self {
        case .today: nil
        case .plan: "plan"
        case .insights: "insights"
        }
    }
}

/// 要素が現れるのを待つ長さ。初回の起動は遅いことがあるので、長めに取る。
let appearTimeout: TimeInterval = 20

extension XCTestCase {
    /// 見本データでアプリを起動する。保存データには触れず、何時に実行しても同じ場面になる。
    ///
    /// - Parameter tab: 最初に開くタブ。タブの切り替えそのものを確かめないテストでは、
    ///   下のタブを押す代わりにこれで開く(OS が作るタブのボタンは、並び順でしか選べないため)。
    @MainActor
    func launchApp(_ scenario: Scenario, language: Language = .english, tab: AppTab = .today) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-sampleData", scenario.rawValue] + language.launchArguments
        if let name = tab.launchArgument {
            app.launchArguments += ["-sampleTab", name]
        }
        app.launch()
        return app
    }

    /// いまの画面全体の写しを、テスト結果に残す。見た目の確認に使う。
    @MainActor
    func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// 要素が現れるまで待つ。現れなければ、その場でテストを失敗にする。
    @MainActor
    @discardableResult
    func waitFor(
        _ element: XCUIElement,
        timeout: TimeInterval = appearTimeout,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "\(element) が現れない", file: file, line: line)
        return element
    }

    /// 要素が消えるまで待つ。
    @MainActor
    func waitForDisappearance(
        of element: XCUIElement,
        timeout: TimeInterval = appearTimeout,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.waitForNonExistence(timeout: timeout), "\(element) が消えない", file: file, line: line)
    }

    /// 条件に合う要素の数が、指定した数になるまで待つ。
    @MainActor
    func waitForCount(
        _ count: Int,
        of query: XCUIElementQuery,
        timeout: TimeInterval = appearTimeout,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count == %d", count), object: query)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "要素の数が \(count) にならない(いまは \(query.count))", file: file, line: line)
    }

    /// 要素が押せる位置に来るまで、画面を上へ送る。
    @MainActor
    func scrollUntilHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maxSwipes: Int = 6,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var swipes = 0
        while !(element.exists && element.isHittable), swipes < maxSwipes {
            app.swipeUp(velocity: .slow)
            swipes += 1
        }
        XCTAssertTrue(element.exists && element.isHittable, "\(element) まで送れない", file: file, line: line)
    }

    /// 要素が画面の上のほうに来るように、画面を送る。カード全体を写しに収めるために使う。
    @MainActor
    func scrollToTop(_ element: XCUIElement, in app: XCUIApplication) {
        scrollUntilHittable(element, in: app, maxSwipes: 3)
        let from = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        // ステータスバーと日付の行のぶんだけ下げた位置まで、ゆっくり引き上げる。勢いで行き過ぎないようにする。
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.14))
        from.press(forDuration: 0.2, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.3)
    }

    /// OS が出す許可の確認(通知など)が出ていれば、許可して閉じる。出ていなければ何もしない。
    @MainActor
    func allowSystemAlertIfPresent(timeout: TimeInterval = 5) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        guard alert.waitForExistence(timeout: timeout) else { return }
        // 許可のボタンは最後に並ぶ。文言は OS の言語で変わるので、位置で選ぶ。
        let buttons = alert.buttons
        buttons.element(boundBy: buttons.count - 1).tap()
    }
}

extension XCUIApplication {
    /// 識別子で要素を探す。種類(ボタン、文字など)は問わない。
    func element(_ identifier: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// 同じ識別子を持つ要素すべて。
    func elements(_ identifier: String) -> XCUIElementQuery {
        descendants(matching: .any).matching(identifier: identifier)
    }

    /// 名前がこの文字で始まる要素。一覧の行のように、複数の文字が1つの要素にまとまるものを探す。
    func element(labelBeginningWith prefix: String) -> XCUIElement {
        descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    /// 下のタブを切り替える。
    ///
    /// タブのボタンは並び順で選ぶ。OS が作るボタンには識別子を確実に付けられず、名前は言語で変わるため。
    func selectTab(_ tab: AppTab) {
        let button = tabBars.firstMatch.buttons.element(boundBy: tab.rawValue)
        XCTAssertTrue(button.waitForExistence(timeout: appearTimeout), "タブが見つからない")
        button.tap()
    }

    /// 画面のいちばん下まで送る。
    func scrollToBottom() {
        // 2 回送れば、どの画面も下端に届く。届いたあとの操作は何も起こさない。
        swipeUp(velocity: .fast)
        swipeUp(velocity: .fast)
    }
}
