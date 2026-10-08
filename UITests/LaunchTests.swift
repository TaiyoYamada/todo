import XCTest

/// 見本データのそれぞれの状態で起動し、「今日」の画面のいちばん上が正しい表示になることを確かめる。
final class LaunchTests: XCTestCase {
    private static let heroes = [
        "today.hero.empty", "today.hero.locked", "today.hero.onPass", "today.hero.countdown", "today.hero.free",
    ]

    // MARK: 英語

    @MainActor
    func testLockedScenarioShowsLockedHero() {
        let app = checkToday(.locked, hero: "today.hero.locked", language: .english)
        // ロック中は、外すための主ボタンが出ている。
        XCTAssertTrue(app.element("today.hero.startFocus").exists)
    }

    @MainActor
    func testCountdownScenarioShowsSlackHero() {
        let app = checkToday(.countdown, hero: "today.hero.countdown", language: .english)
        // まだ終えていない今日の分を、先に進めるよう促している。
        XCTAssertTrue(app.element("today.hero.startFocus").exists)
    }

    @MainActor
    func testFreeScenarioShowsFreeHero() {
        let app = checkToday(.free, hero: "today.hero.free", language: .english)
        // 今日の分はすべて終えているので、進めるものはない。
        XCTAssertFalse(app.element("today.hero.startFocus").exists)
    }

    // MARK: 日本語

    @MainActor
    func testLockedScenarioInJapanese() {
        checkToday(.locked, hero: "today.hero.locked", language: .japanese)
    }

    @MainActor
    func testCountdownScenarioInJapanese() {
        checkToday(.countdown, hero: "today.hero.countdown", language: .japanese)
    }

    @MainActor
    func testFreeScenarioInJapanese() {
        checkToday(.free, hero: "today.hero.free", language: .japanese)
    }

    // MARK: 共通の手順

    /// 起動して、いちばん上の表示と各カードを確かめ、画面の上端と下端の写しを残す。
    @MainActor
    @discardableResult
    private func checkToday(_ scenario: Scenario, hero: String, language: Language) -> XCUIApplication {
        let app = launchApp(scenario, language: language)

        waitFor(app.element(hero))
        for other in Self.heroes where other != hero {
            XCTAssertFalse(app.element(other).exists, "\(other) が同時に出ている")
        }
        XCTAssertTrue(app.element("today.forecast.title").exists)
        XCTAssertTrue(app.element("today.week.title").exists)
        attachScreenshot("Today-\(scenario.rawValue)-top\(language.suffix)")

        app.scrollToBottom()
        waitFor(app.element("today.goals.title"))
        waitFor(app.element("today.tasks.title"))
        attachScreenshot("Today-\(scenario.rawValue)-bottom\(language.suffix)")
        return app
    }
}
