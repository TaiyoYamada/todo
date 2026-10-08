import XCTest

/// 何も登録していない状態から、初回設定を終えて「今日」の画面に着くまで。
final class OnboardingTests: XCTestCase {
    @MainActor
    func testOnboardingCreatesFirstGoal() {
        let app = launchApp(.fresh)
        let next = app.element("onboarding.next")

        // 1. 導入
        waitFor(app.element("onboarding.step.hook"))
        attachScreenshot("Onboarding-1-hook")
        next.tap()

        // 2. 仕組み
        waitFor(app.element("onboarding.step.mechanism"))
        attachScreenshot("Onboarding-2-mechanism")
        next.tap()

        // 3. 最初の目標。名前を入れるまでは先へ進めない。
        waitFor(app.element("onboarding.step.goal"))
        XCTAssertFalse(next.isEnabled)
        let title = waitFor(app.textFields["onboarding.goalTitle"])
        title.tap()
        title.typeText("Thesis")
        XCTAssertTrue(next.isEnabled)
        attachScreenshot("Onboarding-3-goal")
        next.tap()

        // 4. ロックするアプリ。シミュレータでは模擬の許可が下りる。
        waitFor(app.element("onboarding.step.apps"))
        attachScreenshot("Onboarding-4-apps")
        app.element("onboarding.allow").tap()
        waitFor(app.element("onboarding.apps.approved"))
        attachScreenshot("Onboarding-4-apps-approved")
        next.tap()

        // 5. 準備完了
        waitFor(app.element("onboarding.step.ready"))
        attachScreenshot("Onboarding-5-ready")
        app.element("onboarding.start").tap()

        // 終えた直後に、通知の許可を求められる。
        allowSystemAlertIfPresent()

        // 作った目標が「今日」の画面に並ぶ。作った当日はロックしないので、今日は自由。
        waitFor(app.element("today.hero.free"))
        XCTAssertTrue(app.element("today.goals.title").exists)
        XCTAssertTrue(app.staticTexts["Thesis"].exists)
        XCTAssertFalse(app.element("onboarding.next").exists)
        attachScreenshot("Today-after-onboarding")
    }

    @MainActor
    func testBackReturnsToPreviousStep() {
        let app = launchApp(.fresh)

        waitFor(app.element("onboarding.step.hook"))
        app.element("onboarding.next").tap()
        waitFor(app.element("onboarding.step.mechanism"))

        app.element("onboarding.back").tap()
        waitFor(app.element("onboarding.step.hook"))
        attachScreenshot("Onboarding-back-to-hook")
    }
}
