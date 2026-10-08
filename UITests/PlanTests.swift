import XCTest

/// 「予定」の画面から、タスクと目標を追加する。
final class PlanTests: XCTestCase {
    @MainActor
    func testAddTaskFromPlan() {
        let app = launchApp(.countdown)
        waitFor(app.element("today.hero.countdown"))

        app.selectTab(.plan)
        waitFor(app.element("plan.tasks.title"))
        attachScreenshot("Plan")

        let add = app.element("plan.addTask")
        scrollUntilHittable(add, in: app)
        add.tap()

        // 名前を入れるまでは追加できない。
        let title = waitFor(app.textFields["taskEditor.title"])
        XCTAssertFalse(app.element("taskEditor.save").isEnabled)
        title.tap()
        title.typeText("Buy textbook")
        XCTAssertTrue(app.element("taskEditor.save").isEnabled)
        attachScreenshot("TaskEditor")

        app.element("taskEditor.save").tap()
        waitForDisappearance(of: title)

        // 追加したタスクが一覧に並ぶ。
        waitFor(app.element(labelBeginningWith: "Buy textbook"))
        attachScreenshot("Plan-after-adding-task")
    }

    @MainActor
    func testTaskTitleWithDetailsShowsSuggestion() {
        let app = launchApp(.countdown)
        waitFor(app.element("today.hero.countdown"))

        app.selectTab(.plan)
        waitFor(app.element("plan.tasks.title"))
        let add = app.element("plan.addTask")
        scrollUntilHittable(add, in: app)
        add.tap()

        // 名前の欄に締切と所要時間を書くと、読み取った内容が提案として出る。
        let title = waitFor(app.textFields["taskEditor.title"])
        title.tap()
        title.typeText("Report by Friday 2h")
        let suggestion = waitFor(app.element("taskEditor.suggestion"))
        attachScreenshot("TaskEditor-suggestion")

        // 提案を反映すると、名前から締切と所要時間の部分が取り除かれる。
        suggestion.tap()
        waitForDisappearance(of: suggestion)
        XCTAssertEqual(title.value as? String, "Report")
        attachScreenshot("TaskEditor-suggestion-applied")

        app.element("taskEditor.save").tap()
        waitForDisappearance(of: title)
        waitFor(app.element(labelBeginningWith: "Report"))
    }

    @MainActor
    func testAddGoalFromPlan() {
        let app = launchApp(.countdown)
        waitFor(app.element("today.hero.countdown"))

        app.selectTab(.plan)
        waitFor(app.element("plan.addGoal")).tap()

        let title = waitFor(app.textFields["goalEditor.title"])
        XCTAssertFalse(app.element("goalEditor.save").isEnabled)
        title.tap()
        title.typeText("Read papers")
        XCTAssertTrue(app.element("goalEditor.save").isEnabled)
        attachScreenshot("GoalEditor")

        app.element("goalEditor.save").tap()
        waitForDisappearance(of: title)

        waitFor(app.element(labelBeginningWith: "Read papers"))
        attachScreenshot("Plan-after-adding-goal")
    }

    @MainActor
    func testCancelDiscardsNewTask() {
        let app = launchApp(.countdown)
        waitFor(app.element("today.hero.countdown"))

        app.selectTab(.plan)
        waitFor(app.element("plan.tasks.title"))
        let add = app.element("plan.addTask")
        scrollUntilHittable(add, in: app)
        add.tap()

        let title = waitFor(app.textFields["taskEditor.title"])
        title.tap()
        title.typeText("Never mind")
        app.element("taskEditor.cancel").tap()
        waitForDisappearance(of: title)

        XCTAssertFalse(app.element(labelBeginningWith: "Never mind").exists)
    }

    @MainActor
    func testPlanInJapanese() {
        let app = launchApp(.countdown, language: .japanese)
        waitFor(app.element("today.hero.countdown"))

        app.selectTab(.plan)
        waitFor(app.element("plan.goals.title"))
        waitFor(app.element("plan.tasks.title"))
        attachScreenshot("Plan-top-ja")

        app.scrollToBottom()
        waitFor(app.element("plan.closed.title"))
        attachScreenshot("Plan-bottom-ja")
    }
}
