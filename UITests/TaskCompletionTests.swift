import XCTest

/// タスクを、完了の確認(実際にかかった時間を聞く画面)を通して片づける。
final class TaskCompletionTests: XCTestCase {
    /// 見本データの、今日のうちに着手リミットが来るタスク。ロック予報に並ぶ。
    private let todayTask = "Statistics report"

    @MainActor
    func testCompleteTaskFromTimeline() {
        let app = launchApp(.countdown)
        waitFor(app.element("today.hero.countdown"))

        // ロック予報の行にある完了のボタンから片づける。
        let complete = app.element("today.complete.\(todayTask)")
        scrollUntilHittable(complete, in: app)
        complete.tap()

        // 見積もり(90 分)を基準にした選択肢から、実際にかかった時間を選ぶ。
        waitFor(app.element("completion.title"))
        let confirm = app.element("completion.confirm")
        XCTAssertTrue(confirm.exists)
        // 「始める」を押していないので、最初は見積もりどおりが選ばれている。
        XCTAssertTrue(app.element("chip.90").isSelected)
        let longer = app.element("chip.135")
        XCTAssertTrue(longer.exists)
        longer.tap()
        XCTAssertTrue(longer.isSelected)
        attachScreenshot("TaskCompletion")

        confirm.tap()
        waitForDisappearance(of: confirm)

        // 片づけたタスクは、済んだ行として予報に残る。完了のボタンは消える。
        waitForDisappearance(of: complete)
        XCTAssertTrue(app.element("today.item.\(todayTask)").exists)
        attachScreenshot("Today-after-completing-task")

        // 「予定」では、片づけたものの側に移っている。残る未完了は 1 件。
        app.selectTab(.plan)
        waitFor(app.element("plan.tasks.title"))
        XCTAssertEqual(app.elements("plan.task.complete").count, 1)
        attachScreenshot("Plan-after-completing-task")
    }

    @MainActor
    func testCompleteTaskFromComingDeadlines() {
        let app = launchApp(.countdown)
        waitFor(app.element("today.hero.countdown"))

        // 着手リミットが明日以降のタスクは、「この先の締切」に 1 件だけ並ぶ。
        let completeButtons = app.elements("today.task.complete")
        let first = completeButtons.firstMatch
        scrollUntilHittable(first, in: app)
        XCTAssertEqual(completeButtons.count, 1)
        first.tap()

        let confirm = waitFor(app.element("completion.confirm"))
        confirm.tap()
        waitForDisappearance(of: confirm)

        // 片づけると、ほかに先のタスクがないので、カードごと消える。
        waitForCount(0, of: completeButtons)
        XCTAssertFalse(app.element("today.tasks.title").exists)
    }

    @MainActor
    func testNotYetKeepsTaskOpen() {
        let app = launchApp(.countdown)
        waitFor(app.element("today.hero.countdown"))

        let complete = app.element("today.complete.\(todayTask)")
        scrollUntilHittable(complete, in: app)
        complete.tap()

        let cancel = waitFor(app.element("completion.cancel"))
        cancel.tap()
        waitForDisappearance(of: cancel)

        // 完了のボタンは残ったまま。
        XCTAssertTrue(complete.exists)
        XCTAssertEqual(app.elements("today.task.complete").count, 1)
    }
}
