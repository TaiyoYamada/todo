import ComposableArchitecture
import DatabaseClient
import Domain
import Foundation
import NotificationClient
import ShieldClient
import SnapshotClient
import Testing
@testable import AppFeature

/// アプリの外(ウィジェットとスクリーンタイムの拡張機能が読む写し、ロックの指示、通知)への連絡。
@MainActor
@Suite("アプリの外への連絡")
struct AppFeatureSyncTests {
    /// アプリの外へ伝えたこと。
    enum Call: Equatable {
        case snapshot(World)
        case shield(ShieldPlan, World)
        case notifications([LockNotification])
    }

    /// 10/9(金)14:00。
    let start = date(9, 14)
    /// 現在の時刻。途中で進められる。最初は `start`。
    let now = LockIsolated(date(9, 14))
    let clock = TestClock()
    /// アプリの外へ伝えたこと。伝えた順。
    let calls = LockIsolated<[Call]>([])
    /// 1日 30 分の目標。朝からロックする。
    let goal = Goal.fixture()

    private func makeStore() -> TestStoreOf<AppFeature> {
        TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.fix(now: now, database: DatabaseSpy())
            $0.continuousClock = clock
            $0.snapshot.save = { [calls] world in calls.withValue { $0.append(.snapshot(world)) } }
            $0.shield.apply = { [calls] plan, world in calls.withValue { $0.append(.shield(plan, world)) } }
            $0.notifications.replaceAll = { [calls] notifications in
                calls.withValue { $0.append(.notifications(notifications)) }
            }
        }
    }

    private func status(_ world: World) -> LockStatus {
        LockEngine(calendar: tokyo).status(world: world, now: now.value)
    }

    private func plan(_ world: World) -> ShieldPlan {
        ShieldPlan(status: status(world))
    }

    /// `world` を伝えるときの、ひとまとまりの連絡。写し → ロックの指示 → 通知 の順。
    private func sync(_ world: World) -> [Call] {
        [
            .snapshot(world),
            .shield(plan(world), world),
            .notifications(AppFeature.warnings(for: status(world))),
        ]
    }

    // MARK: 保存データが変わったとき

    @Test("保存データが変わると、写し → ロックの指示 → 通知の順に伝える")
    func worldChangeSyncsInOrder() async {
        let store = makeStore()
        // 着手リミットは 16:00。
        let world = World.exact(tasks: [.fixture(dueAt: date(9, 18))])
        let expectedPlan = ShieldPlan(isLocked: false, wakeTimes: [date(9, 16)])

        await store.send(.worldChanged(world)) {
            $0.$board.withLock { $0 = .loaded(world, now: start) }
            $0.appliedPlan = expectedPlan
        }

        // 写しが先。スクリーンタイムの拡張機能が、予約の時刻に最新の状況で判定できるように。
        #expect(
            calls.value == [
                .snapshot(world),
                .shield(expectedPlan, world),
                .notifications(AppFeature.warnings(for: status(world))),
            ]
        )
        // 30 分前の前触れと、始まったときの通知。
        #expect(AppFeature.warnings(for: status(world)).map(\.fireAt) == [date(9, 15, 30), date(9, 16)])
        await store.cancelRemainingEffects()
    }

    @Test("保存データが変わるたびに、ロックの指示が同じでも伝え直す")
    func everyWorldChangeSyncs() async {
        let store = makeStore()
        let locked = World.exact(goals: [goal])
        let lockedPlan = ShieldPlan(isLocked: true, title: "院試")

        await store.send(.worldChanged(locked)) {
            $0.$board.withLock { $0 = .loaded(locked, now: start) }
            $0.appliedPlan = lockedPlan
        }
        #expect(calls.value == sync(locked))

        // ロックに関係しない変更(パスの回数)。指示は同じだが、写しは新しくする必要がある。
        var sameLock = locked
        sameLock.preferences.weeklyPassLimit = 3
        #expect(plan(sameLock) == lockedPlan)
        await store.send(.worldChanged(sameLock)) {
            $0.$board.withLock { $0 = .loaded(sameLock, now: start) }
        }
        #expect(calls.value == sync(locked) + sync(sameLock))

        // 10 分やっても、残りの量は指示に入れないので、指示は変わらない。それでも伝える。
        var progressed = sameLock
        progressed.sessions = [.fixture(startedAt: date(9, 13), minutes: 10)]
        #expect(plan(progressed) == lockedPlan)
        await store.send(.worldChanged(progressed)) {
            $0.$board.withLock { $0 = .loaded(progressed, now: start) }
        }
        #expect(calls.value == sync(locked) + sync(sameLock) + sync(progressed))
        #expect(store.state.appliedPlan == lockedPlan)
        await store.cancelRemainingEffects()
    }

    @Test("今日作った目標は今日はロックしないが、明日の予約のために、保存データごと伝える")
    func goalCreatedTodayIsStillSynced() async {
        let store = makeStore()
        let empty = World.exact()

        await store.send(.worldChanged(empty)) {
            $0.$board.withLock { $0 = .loaded(empty, now: start) }
            $0.appliedPlan = ShieldPlan(isLocked: false)
        }

        // 指示は「ロックしない、予約もなし」のまま変わらない。
        let withGoal = World.exact(goals: [.fixture(createdAt: start)])
        await store.send(.worldChanged(withGoal)) {
            $0.$board.withLock { $0 = .loaded(withGoal, now: start) }
        }
        #expect(
            calls.value.suffix(3) == [
                .snapshot(withGoal),
                .shield(ShieldPlan(isLocked: false), withGoal),
                .notifications([]),
            ]
        )
        await store.cancelRemainingEffects()
    }

    @Test("片づけると、通知の予約は空に置き換わる")
    func completingTaskClearsNotifications() async {
        let store = makeStore()
        let world = World.exact(tasks: [.fixture(dueAt: date(9, 18))])

        await store.send(.worldChanged(world)) {
            $0.$board.withLock { $0 = .loaded(world, now: start) }
            $0.appliedPlan = ShieldPlan(isLocked: false, wakeTimes: [date(9, 16)])
        }

        var completed = world
        completed.tasks[0].completedAt = start
        completed.tasks[0].actualMinutes = 120
        await store.send(.worldChanged(completed)) {
            $0.$board.withLock { $0 = .loaded(completed, now: start) }
            $0.appliedPlan = ShieldPlan(isLocked: false)
        }
        #expect(calls.value.last == .notifications([]))
        #expect(calls.value.count == 6)
        await store.cancelRemainingEffects()
    }

    // MARK: 続けて変わったとき

    @Test("連絡の途中で次の変更が来たら、古い連絡はそこでやめる。古い指示が、新しい指示のあとから伝わることはない")
    func supersededSyncStopsBeforeApplyingStalePlan() async {
        // 1 つ目は、16:00 に着手リミットが来るタスクだけ。2 つ目は、朝からロックする目標が増えている。
        let first = World.exact(tasks: [.fixture(dueAt: date(9, 18))])
        let second = World.exact(goals: [goal], tasks: [.fixture(dueAt: date(9, 18))])
        let store = makeStore()
        // 1 つ目の写しの書き出しを、合図があるまで終わらせない。その間に 2 つ目の変更が届く。
        let firstSnapshot = LockIsolated<CheckedContinuation<Void, Never>?>(nil)
        store.dependencies.snapshot.save = { [calls] world in
            calls.withValue { $0.append(.snapshot(world)) }
            if world == first {
                await withCheckedContinuation { firstSnapshot.setValue($0) }
            }
        }

        await store.send(.worldChanged(first)) {
            $0.$board.withLock { $0 = .loaded(first, now: start) }
            $0.appliedPlan = ShieldPlan(isLocked: false, wakeTimes: [date(9, 16)])
        }
        #expect(calls.value == [.snapshot(first)])

        await store.send(.worldChanged(second)) {
            $0.$board.withLock { $0 = .loaded(second, now: start) }
            $0.appliedPlan = ShieldPlan(isLocked: true, title: "院試", wakeTimes: [date(9, 16)])
        }
        let expected: [Call] = [.snapshot(first)] + sync(second)
        #expect(calls.value == expected)

        // 止めておいた 1 つ目を進める。ロックの指示と通知は、もう伝えない。
        firstSnapshot.value?.resume()
        await Task.megaYield()
        #expect(calls.value == expected)
        #expect(!calls.value.contains(.shield(ShieldPlan(isLocked: false, wakeTimes: [date(9, 16)]), first)))
        await store.cancelRemainingEffects()
    }

    // MARK: 時間が進んだだけのとき

    @Test("時刻が進んだだけでは、ロックの指示が変わらない限り、何も伝えない")
    func timePassingAloneDoesNotSync() async {
        let store = makeStore()
        let locked = World.exact(goals: [goal])

        await store.send(.worldChanged(locked)) {
            $0.$board.withLock { $0 = .loaded(locked, now: start) }
            $0.appliedPlan = ShieldPlan(isLocked: true, title: "院試")
        }
        #expect(calls.value.count == 3)

        now.setValue(start.addingTimeInterval(60))
        await store.send(.becameActive) {
            $0.$board.withLock { $0.status = status(locked) }
        }
        now.setValue(start.addingTimeInterval(120))
        await store.send(.tick) {
            $0.$board.withLock { $0.status = status(locked) }
        }

        #expect(calls.value.count == 3)
        await store.cancelRemainingEffects()
    }

    @Test("アプリに戻ってきたとき、時刻が進んでロックが始まっていれば、状態を計算し直して伝える")
    func becameActiveSyncsWhenPlanChanges() async {
        let store = makeStore()
        // 14:30 からロックする目標。
        let world = World.exact(goals: [.fixture(lockStart: .timeOfDay(minutes: 14 * 60 + 30))])

        await store.send(.worldChanged(world)) {
            $0.$board.withLock { $0 = .loaded(world, now: start) }
            $0.appliedPlan = ShieldPlan(isLocked: false, wakeTimes: [date(9, 14, 30)])
        }
        #expect(store.state.board.status.phase == .free(nextLockAt: date(9, 14, 30)))
        let first = sync(world)
        #expect(calls.value == first)

        now.setValue(date(9, 14, 31))
        await store.send(.becameActive) {
            $0.$board.withLock { $0.status = status(world) }
            $0.appliedPlan = ShieldPlan(isLocked: true, title: "院試")
        }
        #expect(store.state.board.status.isLocked)
        // 時刻だけが理由のときも、伝える順は同じ。
        #expect(
            calls.value == first + [
                .snapshot(world),
                .shield(ShieldPlan(isLocked: true, title: "院試"), world),
                .notifications([]),
            ]
        )
        await store.cancelRemainingEffects()
    }

    @Test("見直しの時刻が来てロックが始まったら伝え、そのあとの見直しでは伝えない")
    func tickSyncsOnlyWhenPlanChanges() async {
        // 13:59:50 に起動。タスクの着手リミットは 14:00 で、10 秒後にロックが始まる。
        now.setValue(date(9, 13, 59, 50))
        let store = makeStore()
        let world = World.exact(tasks: [.fixture(dueAt: date(9, 15), estimateMinutes: 60)])

        await store.send(.worldChanged(world)) {
            $0.$board.withLock { $0 = .loaded(world, now: date(9, 13, 59, 50)) }
            $0.appliedPlan = ShieldPlan(isLocked: false, wakeTimes: [date(9, 14)])
        }
        #expect(calls.value.count == 3)

        now.setValue(date(9, 14, 0, 1))
        await clock.advance(by: .seconds(11))
        await store.receive(\.tick) {
            $0.$board.withLock { $0.status = status(world) }
            $0.appliedPlan = ShieldPlan(isLocked: true, title: "レポート")
        }
        #expect(Array(calls.value.suffix(3)) == sync(world))
        #expect(calls.value.count == 6)

        // 15 秒ごとの見直しでは、指示が同じなので伝えない。
        now.setValue(date(9, 14, 0, 16))
        await clock.advance(by: .seconds(15))
        await store.receive(\.tick) {
            $0.$board.withLock { $0.status = status(world) }
        }
        #expect(calls.value.count == 6)
        await store.cancelRemainingEffects()
    }

    // MARK: 計測中

    @Test("計測中は、今日の分に達する時刻を予約し、時間が進んでも予約をやり直さない")
    func runningFocusKeepsSameWakeTime() async {
        let store = makeStore()
        // 13:50 から計測中。30 分の目標なので、14:20 に今日の分に達する。
        var world = World.exact(goals: [goal], activeFocus: ActiveFocus(goalID: goal.id, startedAt: date(9, 13, 50)))
        // 初回設定の途中にして、計測の画面の復元を避ける(ここでは連絡だけを見る)。
        world.preferences.hasCompletedOnboarding = false
        let running = ShieldPlan(isLocked: true, title: "院試", wakeTimes: [date(9, 14, 20)])

        await store.send(.worldChanged(world)) {
            $0.$board.withLock { $0 = .loaded(world, now: start) }
            $0.onboarding = OnboardingFeature.State()
            $0.appliedPlan = running
        }
        #expect(calls.value.count == 3)

        // 5 分たつと残りは 15 分に減るが、達する時刻は 14:20 のまま。指示は変わらない。
        now.setValue(date(9, 14, 5))
        await store.send(.becameActive) {
            $0.$board.withLock { $0.status = status(world) }
        }
        #expect(plan(world) == running)
        #expect(calls.value.count == 3)

        // 達したら、止めていなくてもロックを外すよう伝える。
        now.setValue(date(9, 14, 20))
        await store.send(.becameActive) {
            $0.$board.withLock { $0.status = status(world) }
            $0.appliedPlan = ShieldPlan(isLocked: false)
        }
        #expect(calls.value.suffix(2).first == .shield(ShieldPlan(isLocked: false), world))
        await store.cancelRemainingEffects()
    }
}
