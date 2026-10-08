import XCTest

/// 下のタブで、3 つの画面を行き来できること。
///
/// ほかのテストは `-sampleTab` で目的の画面を直接開くので、タブを押す動きはここでまとめて確かめる。
final class TabTests: XCTestCase {
    @MainActor
    func testSwitchingTabs() {
        let app = launchApp(.countdown)
        waitFor(app.element("today.hero.countdown"))

        app.selectTab(.plan)
        waitFor(app.element("plan.tasks.title"))
        XCTAssertFalse(app.element("today.hero.countdown").exists)

        app.selectTab(.insights)
        waitFor(app.element("insights.week.title"))
        XCTAssertFalse(app.element("plan.tasks.title").exists)

        app.selectTab(.today)
        waitFor(app.element("today.hero.countdown"))
    }

    @MainActor
    func testLaunchArgumentOpensTab() {
        // 起動引数で開いた画面からも、ほかのタブへ移れる。
        let app = launchApp(.countdown, tab: .insights)
        waitFor(app.element("insights.week.title"))

        app.selectTab(.today)
        waitFor(app.element("today.hero.countdown"))
    }
}
