import ComposableArchitecture
import DatabaseClient
import Domain
import Foundation
import ShieldClient
import Testing
@testable import AppFeature

/// 「アプリの根」のテストのうち、画面の移動に関するもの。1つの型が長くなりすぎないように、ファイルを分けている。
extension AppFeatureTests {
    // MARK: 画面の移動

    @Test("集中を始める依頼で、今日すでに記録した量を引き継いだ計測の画面を開く")
    func startFocusOpensFocus() async {
        let world = World.exact(goals: [goal], sessions: [.fixture(startedAt: date(9, 9), minutes: 12)])
        let store = makeLoadedStore(world)

        await store.send(.today(.startFocusTapped(goal.id)))
        await store.receive(\.today.delegate, .startFocus(goal.id)) {
            $0.destination = .focus(FocusFeature.State(
                goal: goal,
                startedAt: start,
                baseSeconds: 12 * 60,
                dayEnd: date(10, 4)
            ))
        }
    }

    @Test("新しい目標の依頼で、採番した ID と現在の時刻を持つ空の目標を開く")
    func newGoalOpensEditor() async {
        let store = makeLoadedStore(.exact())

        await store.send(.plan(.addGoalTapped))
        await store.receive(\.plan.delegate, .editGoal(nil)) {
            $0.destination = .goalEditor(
                GoalEditorFeature.State(goal: Goal(id: uuid(0), title: "", createdAt: start), isNew: true)
            )
        }
    }

    @Test("目標の編集の依頼で、その目標の編集画面を開く")
    func editGoalOpensEditor() async {
        let store = makeLoadedStore(.exact(goals: [goal]))

        await store.send(.today(.goalTapped(goal.id)))
        await store.receive(\.today.delegate, .editGoal(goal.id)) {
            $0.destination = .goalEditor(GoalEditorFeature.State(goal: goal, isNew: false))
        }
    }

    @Test("新しいタスクの依頼で、締切が明日の 23:59 のタスクを開く")
    func newTaskOpensEditorWithDefaultDueDate() async {
        let store = makeLoadedStore(.exact())

        await store.send(.today(.addTaskTapped))
        await store.receive(\.today.delegate, .editTask(nil)) {
            $0.destination = .taskEditor(
                TaskEditorFeature.State(
                    task: TaskItem(id: uuid(0), title: "", dueAt: date(10, 23, 59), createdAt: start),
                    isNew: true
                )
            )
        }
    }

    @Test("深夜に作るタスクの締切の初期値は、暦の上の翌日の 23:59")
    func defaultDueDateAfterMidnight() async {
        // 10/10 の 1:00。このアプリの1日としてはまだ 10/9 だが、締切は暦で数える。
        now.setValue(date(10, 1))
        let store = makeLoadedStore(.exact())

        await store.send(.plan(.delegate(.editTask(nil)))) {
            $0.destination = .taskEditor(
                TaskEditorFeature.State(
                    task: TaskItem(id: uuid(0), title: "", dueAt: date(11, 23, 59), createdAt: date(10, 1)),
                    isNew: true
                )
            )
        }
    }

    @Test("タスクの編集の依頼で、そのタスクの編集画面を開く")
    func editTaskOpensEditor() async {
        let task = TaskItem.fixture()
        let store = makeLoadedStore(.exact(tasks: [task]))

        await store.send(.plan(.taskTapped(task.id)))
        await store.receive(\.plan.delegate, .editTask(task.id)) {
            $0.destination = .taskEditor(TaskEditorFeature.State(task: task, isNew: false))
        }
    }

    @Test("タスクの完了の依頼で、実際の所要時間を聞く画面を開く")
    func completeTaskOpensCompletion() async {
        let task = TaskItem.fixture()
        let store = makeLoadedStore(.exact(tasks: [task]))

        await store.send(.plan(.completeTaskTapped(task.id)))
        await store.receive(\.plan.delegate, .completeTask(task.id)) {
            $0.destination = .taskCompletion(TaskCompletionFeature.State(task: task))
        }
        // 取りかかった時刻がなければ、測った時間はなく、見積もりが初期値になる。
        #expect(store.state.destination?.taskCompletion?.measuredMinutes == nil)
    }

    @Test("「始める」を押してあったタスクの完了では、取りかかってからの時間を初期値にする")
    func completeStartedTaskPassesMeasuredMinutes() async {
        // 13:22 に取りかかった。いまは 14:00 なので 38 分。5 分刻みに丸めて 40 分。
        let task = TaskItem.fixture(startedAt: date(9, 13, 22))
        let store = makeLoadedStore(.exact(tasks: [task]))

        await store.send(.today(.completeTaskTapped(task.id)))
        await store.receive(\.today.delegate, .completeTask(task.id)) {
            $0.destination = .taskCompletion(TaskCompletionFeature.State(task: task, measuredMinutes: 40))
        }
        #expect(store.state.destination?.taskCompletion?.actualMinutes == 40)
    }

    @Test("タスクの編集画面で完了を押すと、編集画面を完了の確認に入れ替える")
    func completingFromEditorSwitchesToCompletion() async {
        let task = TaskItem.fixture()
        let store = makeLoadedStore(.exact(tasks: [task]))

        await store.send(.today(.delegate(.editTask(task.id)))) {
            $0.destination = .taskEditor(TaskEditorFeature.State(task: task, isNew: false))
        }
        await store.send(.destination(.presented(.taskEditor(.completeTapped))))
        await store.receive(\.destination.taskEditor.delegate, .complete(task)) {
            $0.destination = .taskCompletion(TaskCompletionFeature.State(task: task))
        }
    }

    @Test("編集画面で直した内容は、完了の確認にそのまま引き継ぐ")
    func completingFromEditorCarriesEdits() async {
        // 13:10 に取りかかったタスク。いまは 14:00。
        let task = TaskItem.fixture(estimateMinutes: 60, startedAt: date(9, 13, 10))
        let store = makeLoadedStore(.exact(tasks: [task]))

        await store.send(.today(.delegate(.editTask(task.id)))) {
            $0.destination = .taskEditor(TaskEditorFeature.State(task: task, isNew: false))
        }
        await store.send(.destination(.presented(.taskEditor(.binding(.set(\.task.estimateMinutes, 90)))))) {
            $0.destination?.modify(\.taskEditor) { $0.task.estimateMinutes = 90 }
        }
        await store.send(.destination(.presented(.taskEditor(.completeTapped))))

        var edited = task
        edited.estimateMinutes = 90
        await store.receive(\.destination.taskEditor.delegate, .complete(edited)) {
            // 保存データに届く前でも、直した見積もり(90 分)と、取りかかってからの 50 分で開く。
            $0.destination = .taskCompletion(TaskCompletionFeature.State(task: edited, measuredMinutes: 50))
        }
        #expect(store.state.destination?.taskCompletion?.actualMinutes == 50)
    }

    @Test("設定の依頼で、設定の画面を開く")
    func openSettingsOpensSettings() async {
        let store = makeLoadedStore(.exact())

        await store.send(.today(.delegate(.openSettings))) {
            $0.destination = .settings(SettingsFeature.State())
        }
    }

    @Test("もう存在しない目標やタスクへの依頼では、何も開かない")
    func unknownIDsOpenNothing() async {
        let store = makeLoadedStore(.exact())

        await store.send(.today(.delegate(.startFocus(uuid(9)))))
        await store.send(.today(.delegate(.completeTask(uuid(9)))))

        #expect(store.state.destination == nil)
    }
}
