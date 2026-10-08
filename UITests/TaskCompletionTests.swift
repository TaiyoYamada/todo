import XCTest

/// タスクを、完了の確認(実際にかかった時間を聞く画面)を通して片づける。
final class TaskCompletionTests: XCTestCase {
    @MainActor
    func testCompleteTaskFromToday() {
        let app = launchApp(.countdown)
        waitFor(app.element("today.hero.countdown"))

        // 見本データには、未完了のタスクが 2 件ある。
        let completeButtons = app.elements("today.task.complete")
        let first = completeButtons.firstMatch
        scrollUntilHittable(first, in: app)
        XCTAssertEqual(completeButtons.count, 2)
        first.tap()

        // 見積もり(90 分)を基準にした選択肢から、実際にかかった時間を選ぶ。
        waitFor(app.element("completion.title"))
        let confirm = app.element("completion.confirm")
        XCTAssertTrue(confirm.exists)
        let longer = app.element("chip.135")
        XCTAssertTrue(longer.exists)
        longer.tap()
        XCTAssertTrue(longer.isSelected)
        attachScreenshot("TaskCompletion")

        confirm.tap()
        waitForDisappearance(of: confirm)

        // 片づけたタスクは、締切の一覧から消える。
        waitForCount(1, of: completeButtons)
        attachScreenshot("Today-after-completing-task")

        // 「予定」では、片づけたものの側に移っている。
        app.selectTab(.plan)
        waitFor(app.element("plan.tasks.title"))
        XCTAssertEqual(app.elements("plan.task.complete").count, 1)
        attachScreenshot("Plan-after-completing-task")
    }

    @MainActor
    func testNotYetKeepsTaskOpen() {
        let app = launchApp(.countdown)
        waitFor(app.element("today.hero.countdown"))

        let completeButtons = app.elements("today.task.complete")
        let first = completeButtons.firstMatch
        scrollUntilHittable(first, in: app)
        first.tap()

        let cancel = waitFor(app.element("completion.cancel"))
        cancel.tap()
        waitForDisappearance(of: cancel)

        XCTAssertEqual(completeButtons.count, 2)
    }
}
