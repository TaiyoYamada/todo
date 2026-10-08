import XCTest

/// 設定と振り返りの画面が開くこと。
final class SettingsAndInsightsTests: XCTestCase {
    @MainActor
    func testOpenAndCloseSettings() {
        let app = launchApp(.countdown)
        waitFor(app.element("today.hero.countdown"))

        app.element("today.settings").tap()
        let done = waitFor(app.element("settings.done"))
        attachScreenshot("Settings-top")

        app.scrollToBottom()
        waitFor(app.element("settings.replayOnboarding"))
        attachScreenshot("Settings-bottom")

        done.tap()
        waitForDisappearance(of: done)
        XCTAssertTrue(app.element("today.hero.countdown").exists)
    }

    @MainActor
    func testOpenInsights() {
        checkInsights(language: .english)
    }

    @MainActor
    func testInsightsInJapanese() {
        checkInsights(language: .japanese)
    }

    @MainActor
    private func checkInsights(language: Language) {
        let app = launchApp(.countdown, language: language)
        waitFor(app.element("today.hero.countdown"))

        app.selectTab(.insights)
        waitFor(app.element("insights.week.title"))
        // 見本データには過去の記録があるので、日ごとのグラフも出る。
        XCTAssertTrue(app.element("insights.chart.title").exists)
        attachScreenshot("Insights-top\(language.suffix)")

        app.scrollToBottom()
        waitFor(app.element("insights.calibration.title"))
        waitFor(app.element("insights.tasks.title"))
        attachScreenshot("Insights-bottom\(language.suffix)")
    }
}
