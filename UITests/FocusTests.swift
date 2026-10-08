import XCTest

/// 「今日」の画面から集中の計測を始め、止めて、結果を閉じる。
final class FocusTests: XCTestCase {
    @MainActor
    func testStartStopAndCloseFocus() {
        let app = launchApp(.locked)

        waitFor(app.element("today.hero.startFocus")).tap()

        // 計測中。全画面で、止めるボタンだけがある。
        let stop = waitFor(app.element("focus.stop"))
        attachScreenshot("Focus-running")

        // 止めると、結果が出る。
        stop.tap()
        waitFor(app.element("focus.finished.title"))
        XCTAssertTrue(app.element("focus.continue").exists)
        attachScreenshot("Focus-finished")

        // 閉じると、「今日」の画面に戻る。数秒しかやっていないので、ロックは続いている。
        app.element("focus.close").tap()
        waitFor(app.element("today.hero.locked"))
        XCTAssertFalse(app.element("focus.finished.title").exists)
        attachScreenshot("Today-after-focus")
    }

    @MainActor
    func testContinueResumesAfterStopping() {
        let app = launchApp(.locked)

        waitFor(app.element("today.hero.startFocus")).tap()
        waitFor(app.element("focus.stop")).tap()
        waitFor(app.element("focus.finished.title"))

        // 続けると、計測中の画面に戻る。
        app.element("focus.continue").tap()
        waitFor(app.element("focus.stop"))
        XCTAssertFalse(app.element("focus.finished.title").exists)
        attachScreenshot("Focus-running-after-continue")

        // 後片付け。計測中のまま終えると、Live Activity が残る。
        app.element("focus.stop").tap()
        waitFor(app.element("focus.close")).tap()
        waitFor(app.element("today.hero.locked"))
    }

    @MainActor
    func testStartFocusFromTimeline() {
        let app = launchApp(.locked)
        waitFor(app.element("today.hero.locked"))

        // ロックの理由ではない目標(TOEIC)も、予報の行から先に進められる。
        let start = app.element("today.start.TOEIC")
        scrollUntilHittable(start, in: app)
        start.tap()

        let stop = waitFor(app.element("focus.stop"))
        XCTAssertTrue(app.staticTexts["TOEIC"].exists)
        attachScreenshot("Focus-running-from-timeline")

        stop.tap()
        waitFor(app.element("focus.close")).tap()
        waitFor(app.element("today.hero.locked"))
    }

    /// 計測中にホーム画面へ出て、Live Activity(Dynamic Island)の見た目を写しに残す。
    /// 表示そのものは OS が描くので、ここでは落ちないことだけを確かめる。
    @MainActor
    func testLiveActivityAppearsOnHomeScreen() {
        let app = launchApp(.locked)

        waitFor(app.element("today.hero.startFocus")).tap()
        waitFor(app.element("focus.stop"))

        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(springboard.wait(for: .runningForeground, timeout: appearTimeout))
        // Dynamic Island に出てくるまでの動きを待つ。待つ対象の要素がないので、時間で待つ。
        _ = XCTWaiter().wait(for: [XCTestExpectation(description: "Live Activity が出るのを待つ")], timeout: 2)
        attachScreenshot("LiveActivity-DynamicIsland")

        // アプリに戻ると計測は続いている。止めて、Live Activity を片づける。
        app.activate()
        waitFor(app.element("focus.stop")).tap()
        waitFor(app.element("focus.close")).tap()
        waitFor(app.element("today.hero.locked"))
    }
}
