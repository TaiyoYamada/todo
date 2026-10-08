import ComposableArchitecture
import DatabaseClient
import Domain
import Foundation
import ShieldClient
import Testing
@testable import AppFeature

@MainActor
@Suite("アプリの根")
struct AppFeatureTests {
    /// 10/9(金)14:00。
    let start = date(9, 14)
    /// 現在の時刻。途中で進められる。最初は `start`。
    let now = LockIsolated(date(9, 14))
    let clock = TestClock()
    /// スクリーンタイムの層へ伝えた指示。伝えた順。
    let applied = LockIsolated<[ShieldPlan]>([])
    /// 通知の許可を求めた回数。
    let authorizationRequests = LockIsolated(0)
    /// 1日 30 分の目標。朝からロックする。
    let goal = Goal.fixture()

    private func makeStore(
        database: DatabaseClient? = nil,
        onboarding: OnboardingFeature.State? = nil
    ) -> TestStoreOf<AppFeature> {
        var initialState = AppFeature.State()
        initialState.onboarding = onboarding
        return TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.fix(now: now, database: DatabaseSpy())
            if let database {
                $0.database = database
            }
            $0.continuousClock = clock
            $0.shield.apply = { [applied] plan, _ in applied.withValue { $0.append(plan) } }
            $0.notifications.requestAuthorization = { [authorizationRequests] in
                authorizationRequests.withValue { $0 += 1 }
                return true
            }
        }
    }

    private func status(_ world: World) -> LockStatus {
        LockEngine(calendar: tokyo).status(world: world, now: now.value)
    }

    private func plan(_ world: World) -> ShieldPlan {
        ShieldPlan(status: status(world))
    }

    /// 読み込みを済ませた状態から始める。画面の移動だけを確かめるテストで使う。
    private func makeLoadedStore(
        _ world: World,
        onboarding: OnboardingFeature.State? = nil
    ) -> TestStoreOf<AppFeature> {
        prepareBoard(world, now: now.value)
        return makeStore(onboarding: onboarding)
    }

    // MARK: 起動

    @Test("保存データを読み終える前は、時刻の知らせが来ても何もしない")
    func ignoresTicksBeforeLoad() async {
        let store = makeStore()

        await store.send(.tick)
        await store.send(.becameActive)
        await store.finish()

        #expect(applied.value.isEmpty)
    }

    @Test("最初の読み込みで初回設定が済んでいなければ、初回設定を出す")
    func firstLoadShowsOnboarding() async {
        let store = makeStore()
        let world = World()

        await store.send(.worldChanged(world)) {
            $0.$board.withLock { $0 = .loaded(world, now: start) }
            $0.onboarding = OnboardingFeature.State()
            $0.appliedPlan = ShieldPlan(isLocked: false)
        }
        await store.cancelRemainingEffects()
    }

    @Test("最初の読み込みで初回設定が済んでいれば、そのまま今日の画面を出す")
    func firstLoadSkipsOnboardingWhenCompleted() async {
        let store = makeStore()
        let world = World.exact(goals: [goal])

        await store.send(.worldChanged(world)) {
            $0.$board.withLock { $0 = .loaded(world, now: start) }
            $0.appliedPlan = ShieldPlan(isLocked: true, title: "院試")
        }
        #expect(store.state.onboarding == nil)
        #expect(store.state.destination == nil)
        await store.cancelRemainingEffects()
    }

    @Test("計測中にアプリを閉じていたら、最初の読み込みで計測の画面に戻す")
    func firstLoadRestoresActiveFocus() async {
        let store = makeStore()
        // 朝に 10 分やって記録済み。13:50 から計測を始めたまま、アプリを閉じていた。
        let world = World.exact(
            goals: [goal],
            sessions: [.fixture(startedAt: date(9, 9), minutes: 10)],
            activeFocus: ActiveFocus(goalID: goal.id, startedAt: date(9, 13, 50))
        )

        await store.send(.worldChanged(world)) {
            $0.$board.withLock { $0 = .loaded(world, now: start) }
            // 計測中のぶんは含めず、記録済みの 10 分だけを「すでにやった量」とする。
            $0.destination = .focus(
                FocusFeature.State(
                    goal: goal,
                    startedAt: date(9, 13, 50),
                    baseSeconds: 10 * 60,
                    isResumed: true,
                    dayEnd: date(10, 4)
                )
            )
            // ロックの判定には計測中の 10 分も数えるので、残りは 10 分。達する 14:10 に見直してもらう。
            $0.appliedPlan = ShieldPlan(isLocked: true, title: "院試", wakeTimes: [date(9, 14, 10)])
        }
        await store.cancelRemainingEffects()
    }

    @Test("計測中の目標がもう消えていたら、計測の画面には戻さない")
    func firstLoadIgnoresFocusOfMissingGoal() async {
        let store = makeStore()
        let world = World.exact(activeFocus: ActiveFocus(goalID: uuid(9), startedAt: date(9, 13, 50)))

        await store.send(.worldChanged(world)) {
            $0.$board.withLock { $0 = .loaded(world, now: start) }
            $0.appliedPlan = ShieldPlan(isLocked: false)
        }
        #expect(store.state.destination == nil)
        await store.cancelRemainingEffects()
    }

    @Test("初回設定が済んでいなければ、計測中でも初回設定を先に出す")
    func onboardingTakesPriorityOverFocus() async {
        let store = makeStore()
        var world = World.exact(goals: [goal], activeFocus: ActiveFocus(goalID: goal.id, startedAt: date(9, 13, 50)))
        world.preferences.hasCompletedOnboarding = false

        await store.send(.worldChanged(world)) {
            $0.$board.withLock { $0 = .loaded(world, now: start) }
            $0.onboarding = OnboardingFeature.State()
            // 計測中の 10 分を数えて、残りは 20 分。達する 14:20 に見直してもらう。
            $0.appliedPlan = ShieldPlan(isLocked: true, title: "院試", wakeTimes: [date(9, 14, 20)])
        }
        #expect(store.state.destination == nil)
        await store.cancelRemainingEffects()
    }

    // MARK: 保存データの監視

    @Test("保存データを監視し、変更のたびにロックの状態を計算し直す")
    func observesDatabase() async throws {
        let empty = World.exact()
        let database = DatabaseClient.inMemory(empty)
        let store = makeStore(database: database)

        let observation = await store.send(.task)
        await store.receive(\.worldChanged) {
            $0.$board.withLock { $0 = .loaded(empty, now: start) }
            $0.appliedPlan = ShieldPlan(isLocked: false)
        }
        #expect(store.state.board.status.phase == .free(nextLockAt: nil))

        // 前日に作った目標が増えると、今日の分が残っているのでロックになる。
        try await database.saveGoal(goal)
        let withGoal = World.exact(goals: [goal])
        await store.receive(\.worldChanged) {
            $0.$board.withLock { $0 = .loaded(withGoal, now: start) }
            $0.appliedPlan = ShieldPlan(isLocked: true, title: "院試")
        }
        #expect(store.state.board.status.isLocked)

        // 今日の分を記録すると、ロックが外れる。
        let session = FocusSession.fixture(startedAt: date(9, 13), minutes: 30)
        try await database.addSession(session)
        let done = World.exact(goals: [goal], sessions: [session])
        await store.receive(\.worldChanged) {
            $0.$board.withLock { $0 = .loaded(done, now: start) }
            $0.appliedPlan = ShieldPlan(isLocked: false)
        }
        #expect(store.state.board.status.phase == .free(nextLockAt: date(10, 4)))

        // 監視をやめると、そこから始まった見直しの予約も一緒に止まる。
        await observation.cancel()
    }

    // MARK: 時刻による見直し

    @Test("次に状態が変わる時刻で計算し直し、そのあとも見直しを予約し続ける")
    func tickIsRescheduled() async {
        // 13:59:50 に起動。タスクの着手リミットは 14:00 で、10 秒後にロックが始まる。
        now.setValue(date(9, 13, 59, 50))
        let store = makeStore()
        let world = World.exact(tasks: [.fixture(dueAt: date(9, 15), estimateMinutes: 60)])

        await store.send(.worldChanged(world)) {
            $0.$board.withLock { $0 = .loaded(world, now: date(9, 13, 59, 50)) }
            $0.appliedPlan = ShieldPlan(isLocked: false, wakeTimes: [date(9, 14)])
        }

        // 変わる時刻の直後に見直す。ちょうど 10 秒では、まだ来ない。
        await clock.advance(by: .seconds(10))
        await store.send(.binding(.set(\.selectedTab, .plan))) {
            $0.selectedTab = .plan
        }

        now.setValue(date(9, 14, 0, 1))
        await clock.advance(by: .seconds(1))
        await store.receive(\.tick) {
            $0.$board.withLock { $0.status = status(world) }
            $0.appliedPlan = ShieldPlan(isLocked: true, title: "レポート")
        }
        #expect(store.state.board.status.isLocked)
        #expect(applied.value.count == 2)

        // 次に変わる予定が遠くても、15 秒ごとには見直す。
        await clock.advance(by: .seconds(14))
        await store.send(.binding(.set(\.selectedTab, .today))) {
            $0.selectedTab = .today
        }
        await clock.advance(by: .seconds(1))
        await store.receive(\.tick)

        await clock.advance(by: .seconds(15))
        await store.receive(\.tick)

        // 状態が変わっていないので、伝え直してはいない。
        #expect(applied.value.count == 2)
        await store.cancelRemainingEffects()
    }

    // MARK: 初回設定のやり直し

    @Test("あとから初回設定が未完了に戻ったら、開いている画面を閉じて初回設定を出す")
    func replayOnboardingClosesDestination() async {
        let store = makeStore()
        var world = World.exact(goals: [goal])

        await store.send(.worldChanged(world)) {
            $0.$board.withLock { $0 = .loaded(world, now: start) }
            $0.appliedPlan = plan(world)
        }
        await store.send(.today(.settingsTapped))
        await store.receive(\.today.delegate, .openSettings) {
            $0.destination = .settings(SettingsFeature.State())
        }

        // 設定で「はじめの説明をもう一度見る」を選ぶと、保存データがこう変わる。
        world.preferences.hasCompletedOnboarding = false
        await store.send(.worldChanged(world)) {
            $0.$board.withLock { $0 = .loaded(world, now: start) }
            $0.destination = nil
            $0.onboarding = OnboardingFeature.State()
        }

        // 初回設定の途中で保存データが変わっても、最初からやり直しにはならない。
        await store.send(.onboarding(.nextTapped)) {
            $0.onboarding?.step = .mechanism
        }
        world.preferences.weeklyPassLimit = 3
        await store.send(.worldChanged(world)) {
            $0.$board.withLock { $0 = .loaded(world, now: start) }
        }
        #expect(store.state.onboarding?.step == .mechanism)

        await store.send(.onboarding(.delegate(.finished))) {
            $0.onboarding = nil
        }
        await store.cancelRemainingEffects()
    }

    @Test("初回設定を終える途中の「まだ済んでいない」保存データでは、初回設定を開き直さない")
    func finishingOnboardingDoesNotReplay() async {
        let store = makeStore()
        var world = World()

        // 初めての起動。初回設定が出る。
        await store.send(.worldChanged(world)) {
            $0.$board.withLock { $0 = .loaded(world, now: start) }
            $0.onboarding = OnboardingFeature.State()
            $0.appliedPlan = ShieldPlan(isLocked: false)
        }
        // 終了の知らせが、保存データの変更より先に届く。
        await store.send(.onboarding(.delegate(.finished))) {
            $0.onboarding = nil
        }

        // 済ませた印がまだ付いていない保存データが届いても、「済み」から戻ったわけではないので開かない。
        world.goals = [.fixture(createdAt: start)]
        await store.send(.worldChanged(world)) {
            $0.$board.withLock { $0 = .loaded(world, now: start) }
        }
        #expect(store.state.onboarding == nil)

        world.preferences.hasCompletedOnboarding = true
        await store.send(.worldChanged(world)) {
            $0.$board.withLock { $0 = .loaded(world, now: start) }
        }
        #expect(store.state.onboarding == nil)
        await store.cancelRemainingEffects()
    }

    @Test("初回設定を開き直すのは、「済み」から「まだ」に変わった瞬間の 1 回だけ")
    func replayOnboardingOnlyOnTransition() async {
        let store = makeStore()
        var world = World.exact()

        await store.send(.worldChanged(world)) {
            $0.$board.withLock { $0 = .loaded(world, now: start) }
            $0.appliedPlan = ShieldPlan(isLocked: false)
        }

        // 済み → まだ。開き直す。
        world.preferences.hasCompletedOnboarding = false
        await store.send(.worldChanged(world)) {
            $0.$board.withLock { $0 = .loaded(world, now: start) }
            $0.onboarding = OnboardingFeature.State()
        }
        // 説明だけ見て、目標を作らずに終える。終了の知らせが先に届く。
        await store.send(.onboarding(.delegate(.finished))) {
            $0.onboarding = nil
        }

        // まだ → まだ(ほかの設定が変わっただけ)。開き直さない。
        world.preferences.weeklyPassLimit = 1
        await store.send(.worldChanged(world)) {
            $0.$board.withLock { $0 = .loaded(world, now: start) }
        }
        #expect(store.state.onboarding == nil)

        // まだ → 済み。開き直さない。
        world.preferences.hasCompletedOnboarding = true
        await store.send(.worldChanged(world)) {
            $0.$board.withLock { $0 = .loaded(world, now: start) }
        }
        #expect(store.state.onboarding == nil)

        // もう一度、済み → まだ。今度は開き直す。
        world.preferences.hasCompletedOnboarding = false
        await store.send(.worldChanged(world)) {
            $0.$board.withLock { $0 = .loaded(world, now: start) }
            $0.onboarding = OnboardingFeature.State()
        }
        await store.cancelRemainingEffects()
    }

    @Test("初回設定を終えた直後に、通知の許可を求める")
    func finishingOnboardingRequestsNotificationPermission() async {
        let store = makeLoadedStore(World(), onboarding: OnboardingFeature.State())

        await store.send(.onboarding(.delegate(.finished))) {
            $0.onboarding = nil
        }
        await store.finish()

        #expect(authorizationRequests.value == 1)
    }

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
