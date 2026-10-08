import ComposableArchitecture
import Domain
import Foundation
import Testing
@testable import AppFeature

@MainActor
@Suite("今日の画面")
struct TodayFeatureTests {
    /// 10/9(金)14:00。
    let now = date(9, 14)
    let spy = DatabaseSpy()

    private func makeStore(_ world: World) -> TestStoreOf<TodayFeature> {
        prepareBoard(world, now: now)
        return TestStore(initialState: TodayFeature.State()) {
            TodayFeature()
        } withDependencies: {
            $0.fix(now: LockIsolated(now), database: spy)
        }
    }

    // MARK: 表示

    @Test("いちばん上の表示は、共有しているロックの状態から決まる")
    func heroFollowsBoard() {
        let store = makeStore(.exact(goals: [.fixture()]))
        let reason = LockReason(source: .goal(uuid(1)), title: "院試", startsAt: date(9, 4), remainingSeconds: 30 * 60)
        #expect(store.state.hero == .locked(primary: reason, others: 0))
    }

    // MARK: 画面の移動

    @Test("目標の操作は、開く画面の依頼として親に伝わる")
    func goalActionsDelegate() async {
        let store = makeStore(.exact(goals: [.fixture()]))

        await store.send(.startFocusTapped(uuid(1)))
        await store.receive(\.delegate, .startFocus(uuid(1)))

        await store.send(.goalTapped(uuid(1)))
        await store.receive(\.delegate, .editGoal(uuid(1)))

        await store.send(.addGoalTapped)
        await store.receive(\.delegate, .editGoal(nil))
    }

    @Test("タスクの操作は、開く画面の依頼として親に伝わる")
    func taskActionsDelegate() async {
        let store = makeStore(.exact(tasks: [.fixture()]))

        await store.send(.taskTapped(uuid(100)))
        await store.receive(\.delegate, .editTask(uuid(100)))

        await store.send(.completeTaskTapped(uuid(100)))
        await store.receive(\.delegate, .completeTask(uuid(100)))

        await store.send(.addTaskTapped)
        await store.receive(\.delegate, .editTask(nil))
    }

    @Test("設定のボタンは、設定を開く依頼として親に伝わる")
    func settingsDelegates() async {
        let store = makeStore(World())

        await store.send(.settingsTapped)
        await store.receive(\.delegate, .openSettings)
    }

    // MARK: タスクに取りかかる

    @Test("「いま始める」を押すと、取りかかった時刻を付けてタスクを保存する")
    func startTaskSavesStartedAt() async {
        // 着手リミット(13:00)を過ぎていて、このタスクでロックされている。
        let task = TaskItem.fixture(dueAt: date(9, 15))
        let store = makeStore(.exact(tasks: [task]))
        #expect(store.state.board.status.isLocked)

        await store.send(.startTaskTapped(task.id))
        await store.finish()

        // ほかの内容は変えない。完了にもしない。
        #expect(spy.writes == [.saveTask(.fixture(dueAt: date(9, 15), startedAt: now))])
    }

    @Test("ロックされる前のタスクでも、取りかかった時刻を残せる")
    func startTaskBeforeLock() async {
        let task = TaskItem.fixture()
        let store = makeStore(.exact(tasks: [task]))
        #expect(!store.state.board.status.isLocked)

        await store.send(.startTaskTapped(task.id))
        await store.finish()

        #expect(spy.writes == [.saveTask(.fixture(startedAt: now))])
    }

    @Test("すでに取りかかっているタスクは、時刻を上書きしない")
    func startTaskIgnoredWhenAlreadyStarted() async {
        let task = TaskItem.fixture(startedAt: date(9, 13, 10))
        let store = makeStore(.exact(tasks: [task]))

        await store.send(.startTaskTapped(task.id))
        await store.finish()

        #expect(spy.writes.isEmpty)
    }

    @Test("片づけたタスクと、もう存在しないタスクには、何もしない")
    func startTaskIgnoredWhenClosedOrMissing() async {
        let store = makeStore(
            .exact(
                tasks: [
                    .fixture(100, completedAt: date(9, 10)),
                    .fixture(101, withdrawnAt: date(9, 11)),
                ]
            )
        )

        await store.send(.startTaskTapped(uuid(100)))
        await store.send(.startTaskTapped(uuid(101)))
        await store.send(.startTaskTapped(uuid(999)))
        await store.finish()

        #expect(spy.writes.isEmpty)
    }

    // MARK: パス

    @Test("ロック中で回数が残っていれば、パスの使用を保存する")
    func usePassWhileLocked() async {
        let store = makeStore(.exact(goals: [.fixture()]))

        await store.send(.usePassConfirmed)
        await store.finish()

        #expect(spy.writes == [.addPassUse(PassUse(id: uuid(0), usedAt: now, minutes: 15))])
    }

    @Test("パスの長さは、設定の値を使う")
    func passUsesConfiguredMinutes() async {
        var world = World.exact(goals: [.fixture()])
        world.preferences.passMinutes = 30
        let store = makeStore(world)

        await store.send(.usePassConfirmed)
        await store.finish()

        #expect(spy.writes == [.addPassUse(PassUse(id: uuid(0), usedAt: now, minutes: 30))])
    }

    @Test("ロックされていなければ、パスは使えない")
    func passIgnoredWhenFree() async {
        let store = makeStore(.exact(tasks: [.fixture()]))

        await store.send(.usePassConfirmed)
        await store.finish()

        #expect(spy.writes.isEmpty)
    }

    @Test("今週の回数を使い切っていれば、パスは使えない")
    func passIgnoredWhenNoneLeft() async {
        // 週は月曜(10/5)に始まる。火曜と水曜に 1 回ずつ使った。
        let world = World.exact(
            goals: [.fixture()],
            passUses: [
                PassUse(id: uuid(300), usedAt: date(6, 10), minutes: 15),
                PassUse(id: uuid(301), usedAt: date(7, 10), minutes: 15),
            ]
        )
        let store = makeStore(world)

        await store.send(.usePassConfirmed)
        await store.finish()

        #expect(spy.writes.isEmpty)
    }

    @Test("パスを使っている最中に、重ねては使えない")
    func passIgnoredWhileOnPass() async {
        let world = World.exact(
            goals: [.fixture()],
            passUses: [PassUse(id: uuid(300), usedAt: date(9, 13, 50), minutes: 15)]
        )
        let store = makeStore(world)

        await store.send(.usePassConfirmed)
        await store.finish()

        #expect(spy.writes.isEmpty)
    }
}
