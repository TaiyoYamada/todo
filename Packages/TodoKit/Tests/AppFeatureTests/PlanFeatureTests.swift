import ComposableArchitecture
import Domain
import Foundation
import Testing

@testable import AppFeature

@MainActor
@Suite("予定の画面")
struct PlanFeatureTests {
    /// 10/9(金)14:00。
    let now = date(9, 14)

    private func makeStore(_ world: World) -> TestStoreOf<PlanFeature> {
        prepareBoard(world, now: now)
        return TestStore(initialState: PlanFeature.State()) {
            PlanFeature()
        }
    }

    // MARK: 画面の移動

    @Test("目標の操作は、開く画面の依頼として親に伝わる")
    func goalActionsDelegate() async {
        let store = makeStore(.exact(goals: [.fixture()]))

        await store.send(.addGoalTapped)
        await store.receive(\.delegate, .editGoal(nil))

        await store.send(.goalTapped(uuid(1)))
        await store.receive(\.delegate, .editGoal(uuid(1)))
    }

    @Test("タスクの操作は、開く画面の依頼として親に伝わる")
    func taskActionsDelegate() async {
        let store = makeStore(.exact(tasks: [.fixture()]))

        await store.send(.addTaskTapped)
        await store.receive(\.delegate, .editTask(nil))

        await store.send(.taskTapped(uuid(100)))
        await store.receive(\.delegate, .editTask(uuid(100)))

        await store.send(.completeTaskTapped(uuid(100)))
        await store.receive(\.delegate, .completeTask(uuid(100)))
    }

    // MARK: 一覧

    @Test("未完了のタスクは、締切ではなく着手リミットが近い順に並ぶ")
    func openTasksSortedByStartLimit() {
        let world = World.exact(
            tasks: [
                // 締切 22:00、所要 30 分。着手リミットは 21:30。
                .fixture(100, title: "短いもの", dueAt: date(9, 22), estimateMinutes: 30),
                // 締切 23:59、所要 240 分。着手リミットは 19:59。締切は遅いが、先に始めないと間に合わない。
                .fixture(101, title: "長いもの", dueAt: date(9, 23, 59), estimateMinutes: 240),
                .fixture(102, title: "済んだもの", completedAt: date(9, 10)),
                .fixture(103, title: "やめたもの", withdrawnAt: date(9, 11)),
            ]
        )
        prepareBoard(world, now: now)

        #expect(PlanFeature.State().openTasks.map(\.title) == ["長いもの", "短いもの"])
    }

    @Test("片づけたタスクは、完了または取り下げが新しい順に並ぶ")
    func closedTasksSortedNewestFirst() {
        let world = World.exact(
            tasks: [
                .fixture(100, title: "おととい完了", completedAt: date(7, 20)),
                .fixture(101, title: "けさ取り下げ", withdrawnAt: date(9, 8)),
                .fixture(102, title: "きのう完了", completedAt: date(8, 20)),
                .fixture(103, title: "未完了"),
            ]
        )
        prepareBoard(world, now: now)

        #expect(PlanFeature.State().closedTasks.map(\.title) == ["けさ取り下げ", "きのう完了", "おととい完了"])
    }

    @Test("片づけたタスクは、直近の 20 件だけを出す")
    func closedTasksAreCapped() {
        // 10/1 から毎日 1 件ずつ、25 日ぶん。
        let tasks = (1...25).map { day in
            TaskItem.fixture(100 + day, title: "\(day)日", completedAt: date(day, 12))
        }
        prepareBoard(.exact(tasks: tasks), now: date(26, 14))

        let closed = PlanFeature.State().closedTasks
        #expect(closed.count == 20)
        #expect(closed.first?.title == "25日")
        #expect(closed.last?.title == "6日")
    }
}
