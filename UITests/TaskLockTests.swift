import XCTest

/// タスクの着手リミットを過ぎてロックされたときの、「今日」の画面のいちばん上。
///
/// 目標のロックと違って計測はなく、「いま始める」で取りかかった時刻を残し、終えたら完了にする。
final class TaskLockTests: XCTestCase {
    @MainActor
    func testStartNowThenComplete() {
        let app = launchApp(.taskLocked)
        waitFor(app.element("today.hero.locked"))

        // 主ボタンは「いま始める」。その下に、控えめな「もう終わっている」。
        let start = waitFor(app.element("today.hero.startTask"))
        XCTAssertTrue(app.element("today.hero.completeTask").exists)
        XCTAssertFalse(app.element("today.hero.startFocus").exists)
        XCTAssertFalse(app.element(labelBeginningWith: "Working").exists)
        attachScreenshot("Today-taskLocked-before-start")

        // 始めると、経過時間が出て、主ボタンが完了に替わる。始めただけでは、ロックは外れない。
        start.tap()
        waitForDisappearance(of: start)
        waitFor(app.element(labelBeginningWith: "Working"))
        let complete = waitFor(app.element("today.hero.completeTask"))
        XCTAssertTrue(app.element("today.hero.locked").exists)
        attachScreenshot("Today-taskLocked-after-start")

        // 完了の確認では、取りかかってからの時間(5 分に切り上げ)が最初に選ばれている。
        complete.tap()
        let confirm = waitFor(app.element("completion.confirm"))
        XCTAssertTrue(app.element("chip.5").isSelected)
        XCTAssertFalse(app.element("chip.90").isSelected)
        attachScreenshot("TaskCompletion-measured")

        // 片づけるとロックが外れ、次のロック(TOEIC)までの余裕に替わる。
        confirm.tap()
        waitForDisappearance(of: confirm)
        waitFor(app.element("today.hero.countdown"))
        XCTAssertFalse(app.element("today.hero.completeTask").exists)
        attachScreenshot("Today-taskLocked-after-complete")
    }

    @MainActor
    func testAlreadyDoneSkipsStart() {
        let app = launchApp(.taskLocked)
        waitFor(app.element("today.hero.locked"))
        waitFor(app.element("today.hero.startTask"))

        // 始めるのを押さずに終えていた場合。測った時間はないので、見積もり(90 分)が最初に選ばれている。
        app.element("today.hero.completeTask").tap()
        let cancel = waitFor(app.element("completion.cancel"))
        XCTAssertTrue(app.element("chip.90").isSelected)
        XCTAssertFalse(app.element("chip.5").exists)

        // まだ終わっていなければ、ロックはそのまま。「いま始める」も残る。
        cancel.tap()
        waitForDisappearance(of: cancel)
        XCTAssertTrue(app.element("today.hero.locked").exists)
        XCTAssertTrue(app.element("today.hero.startTask").exists)
    }

    @MainActor
    func testTaskLockedInJapanese() {
        let app = launchApp(.taskLocked, language: .japanese)
        waitFor(app.element("today.hero.locked"))

        let start = waitFor(app.element("today.hero.startTask"))
        attachScreenshot("Today-taskLocked-before-start-ja")

        start.tap()
        waitForDisappearance(of: start)
        waitFor(app.element("today.hero.completeTask"))
        attachScreenshot("Today-taskLocked-after-start-ja")
    }
}
