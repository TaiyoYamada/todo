import ComposableArchitecture
import Domain
import Foundation
import SharedCore
import ShieldClient
import Testing
@testable import AppFeature

@MainActor
@Suite("アプリの外から開く")
struct AppFeatureDeepLinkTests {
    /// 10/9(金)14:00。
    let start = date(9, 14)
    /// 1日 30 分の目標。朝からロックする。
    let goal = Goal.fixture()

    /// 保存データを読み終えた状態のストア。
    private func makeLoadedStore(
        _ world: World,
        onboarding: OnboardingFeature.State? = nil
    ) -> TestStoreOf<AppFeature> {
        prepareBoard(world, now: start)
        return makeStore(onboarding: onboarding)
    }

    private func makeStore(onboarding: OnboardingFeature.State? = nil) -> TestStoreOf<AppFeature> {
        var initialState = AppFeature.State()
        initialState.onboarding = onboarding
        return TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.fix(now: LockIsolated(start), database: DatabaseSpy())
            // 保存データの読み込みまで進めるテストのために、見直しの予約とロックの連絡を受け止める。
            $0.continuousClock = TestClock()
            $0.shield.apply = { _, _ in }
        }
    }

    @Test("計測を始めるリンクは、ロックの理由になっている目標の計測を開く")
    func focusLinkOpensLockedGoal() async {
        // 先頭の目標は 20:00 からのロックで、まだ理由になっていない。2つ目が朝からロック中。
        let later = Goal.fixture(1, title: "TOEIC", lockStart: .timeOfDay(minutes: 20 * 60))
        let locked = Goal.fixture(2, title: "院試")
        let world = World.exact(
            goals: [later, locked],
            sessions: [.fixture(goal: 2, startedAt: date(9, 9), minutes: 5)]
        )
        let store = makeLoadedStore(world)

        await store.send(.openDeepLink(.focus)) {
            $0.destination = .focus(FocusFeature.State(goal: locked, startedAt: start, baseSeconds: 5 * 60))
        }
    }

    @Test("ロックの理由になっている目標がなければ、まだ終えていない今日の分の計測を開く")
    func focusLinkOpensFirstIncompleteGoal() async {
        // 1つ目は今日の分を終えている。2つ目は 20:00 からのロックで、まだ終えていない。
        let done = Goal.fixture(1, title: "院試")
        let pending = Goal.fixture(2, title: "TOEIC", lockStart: .timeOfDay(minutes: 20 * 60))
        let world = World.exact(
            goals: [done, pending],
            sessions: [.fixture(goal: 1, startedAt: date(9, 9), minutes: 30)]
        )
        let store = makeLoadedStore(world)

        await store.send(.openDeepLink(.focus)) {
            $0.destination = .focus(FocusFeature.State(goal: pending, startedAt: start, baseSeconds: 0))
        }
    }

    @Test("タスクでロックされていても、計測を始めるリンクは目標の計測を開く")
    func focusLinkSkipsTaskReasons() async {
        let pending = Goal.fixture(lockStart: .timeOfDay(minutes: 20 * 60))
        // 着手リミットは 13:00 で、もう過ぎている。
        let world = World.exact(goals: [pending], tasks: [.fixture(dueAt: date(9, 15))])
        let store = makeLoadedStore(world)
        #expect(store.state.board.status.isLocked)

        await store.send(.openDeepLink(.focus)) {
            $0.destination = .focus(FocusFeature.State(goal: pending, startedAt: start, baseSeconds: 0))
        }
    }

    @Test("進める目標がなければ、計測を始めるリンクは今日の画面を出すだけにする")
    func focusLinkWithNothingToDoShowsToday() async {
        let world = World.exact(goals: [goal], sessions: [.fixture(startedAt: date(9, 9), minutes: 30)])
        let store = makeLoadedStore(world)

        await store.send(.binding(.set(\.selectedTab, .insights))) {
            $0.selectedTab = .insights
        }
        await store.send(.openDeepLink(.focus)) {
            $0.selectedTab = .today
        }
        #expect(store.state.destination == nil)
    }

    @Test("タスクを追加するリンクは、新しいタスクの編集画面を開く")
    func addTaskLinkOpensEditor() async {
        let store = makeLoadedStore(.exact(goals: [goal]))

        await store.send(.openDeepLink(.addTask)) {
            $0.destination = .taskEditor(
                TaskEditorFeature.State(
                    task: TaskItem(id: uuid(0), title: "", dueAt: date(10, 23, 59), createdAt: start),
                    isNew: true
                )
            )
        }
    }

    // MARK: 保存データを読み終える前のリンク

    @Test("保存データを読み終える前のリンクは、覚えておいて、読み終えたら開く")
    func deepLinkBeforeLoadOpensAfterFirstLoad() async {
        let store = makeStore()
        let world = World.exact(goals: [goal])

        // アプリが起動していない状態から開かれると、読み込みより先にリンクが届く。
        await store.send(.openDeepLink(.addTask)) {
            $0.pendingDeepLink = .addTask
        }
        #expect(store.state.destination == nil)

        await store.send(.worldChanged(world)) {
            $0.$board.withLock { $0 = .loaded(world, now: start) }
            $0.appliedPlan = ShieldPlan(isLocked: true, title: "院試")
            $0.pendingDeepLink = nil
            $0.destination = .taskEditor(
                TaskEditorFeature.State(
                    task: TaskItem(id: uuid(0), title: "", dueAt: date(10, 23, 59), createdAt: start),
                    isNew: true
                )
            )
        }
        await store.cancelRemainingEffects()
    }

    @Test("読み終える前に計測を始めるリンクが届いたら、読み終えてから、ロックの理由の目標の計測を開く")
    func focusLinkBeforeLoadOpensFocusAfterFirstLoad() async {
        let store = makeStore()
        let world = World.exact(goals: [goal], sessions: [.fixture(startedAt: date(9, 9), minutes: 5)])

        await store.send(.openDeepLink(.focus)) {
            $0.pendingDeepLink = .focus
        }
        await store.send(.worldChanged(world)) {
            $0.$board.withLock { $0 = .loaded(world, now: start) }
            $0.appliedPlan = ShieldPlan(isLocked: true, title: "院試")
            $0.pendingDeepLink = nil
            $0.destination = .focus(FocusFeature.State(goal: goal, startedAt: start, baseSeconds: 5 * 60))
        }
        await store.cancelRemainingEffects()
    }

    @Test("読み終える前にリンクが続けて届いたら、最後のものだけを開く")
    func lastDeepLinkBeforeLoadWins() async {
        let store = makeStore()
        let world = World.exact(goals: [goal])

        await store.send(.openDeepLink(.addTask)) {
            $0.pendingDeepLink = .addTask
        }
        await store.send(.openDeepLink(.focus)) {
            $0.pendingDeepLink = .focus
        }
        await store.send(.worldChanged(world)) {
            $0.$board.withLock { $0 = .loaded(world, now: start) }
            $0.appliedPlan = ShieldPlan(isLocked: true, title: "院試")
            $0.pendingDeepLink = nil
            $0.destination = .focus(FocusFeature.State(goal: goal, startedAt: start, baseSeconds: 0))
        }
        await store.cancelRemainingEffects()
    }

    @Test("覚えておいたリンクを開くのは最初の読み込みのときだけで、次の変更では開き直さない")
    func pendingDeepLinkHandledOnlyOnce() async {
        let store = makeStore()
        var world = World.exact(goals: [goal])

        await store.send(.openDeepLink(.addTask)) {
            $0.pendingDeepLink = .addTask
        }
        await store.send(.worldChanged(world)) {
            $0.$board.withLock { $0 = .loaded(world, now: start) }
            $0.appliedPlan = ShieldPlan(isLocked: true, title: "院試")
            $0.pendingDeepLink = nil
            $0.destination = .taskEditor(
                TaskEditorFeature.State(
                    task: TaskItem(id: uuid(0), title: "", dueAt: date(10, 23, 59), createdAt: start),
                    isNew: true
                )
            )
        }
        await store.send(.destination(.dismiss)) {
            $0.destination = nil
        }

        world.preferences.weeklyPassLimit = 3
        await store.send(.worldChanged(world)) {
            $0.$board.withLock { $0 = .loaded(world, now: start) }
        }
        #expect(store.state.destination == nil)
        await store.cancelRemainingEffects()
    }

    @Test("読み終えてみたら初回設定がまだだったときは、覚えておいたリンクを捨てて、初回設定を出す")
    func pendingDeepLinkDroppedWhenOnboardingNeeded() async {
        let store = makeStore()
        let world = World()

        await store.send(.openDeepLink(.addTask)) {
            $0.pendingDeepLink = .addTask
        }
        await store.send(.worldChanged(world)) {
            $0.$board.withLock { $0 = .loaded(world, now: start) }
            $0.appliedPlan = ShieldPlan(isLocked: false)
            $0.onboarding = OnboardingFeature.State()
            $0.pendingDeepLink = nil
        }
        #expect(store.state.destination == nil)
        await store.cancelRemainingEffects()
    }

    @Test("読み終えてみたら計測の途中だったときは、計測の画面に戻すほうを優先し、リンクでは割り込まない")
    func pendingDeepLinkDoesNotInterruptRestoredFocus() async {
        let store = makeStore()
        let world = World.exact(goals: [goal], activeFocus: ActiveFocus(goalID: goal.id, startedAt: date(9, 13, 50)))

        await store.send(.openDeepLink(.addTask)) {
            $0.pendingDeepLink = .addTask
        }
        await store.send(.worldChanged(world)) {
            $0.$board.withLock { $0 = .loaded(world, now: start) }
            $0.appliedPlan = ShieldPlan(isLocked: true, title: "院試", wakeTimes: [date(9, 14, 20)])
            $0.pendingDeepLink = nil
            $0.destination = .focus(
                FocusFeature.State(goal: goal, startedAt: date(9, 13, 50), baseSeconds: 0, isResumed: true)
            )
        }
        await store.cancelRemainingEffects()
    }

    // MARK: 割り込まない場面

    @Test("初回設定の途中のリンクは、無視する")
    func deepLinkIgnoredDuringOnboarding() async {
        let store = makeLoadedStore(.exact(goals: [goal]), onboarding: OnboardingFeature.State())

        await store.send(.openDeepLink(.focus))
        await store.send(.openDeepLink(.addTask))

        #expect(store.state.destination == nil)
        #expect(store.state.onboarding != nil)
    }

    @Test("すでに何かの画面を開いているときのリンクは、割り込まない")
    func deepLinkIgnoredWhileDestinationOpen() async {
        let store = makeLoadedStore(.exact(goals: [goal]))

        await store.send(.today(.delegate(.openSettings))) {
            $0.destination = .settings(SettingsFeature.State())
        }
        await store.send(.openDeepLink(.focus))
        await store.send(.openDeepLink(.addTask))

        #expect(store.state.destination == .settings(SettingsFeature.State()))
    }

    @Test("リンクの URL は、行き先に読み替えられる")
    func deepLinkParsesURL() throws {
        #expect(try DeepLink(url: #require(URL(string: "lockcast://focus"))) == .focus)
        #expect(try DeepLink(url: #require(URL(string: "lockcast://add-task"))) == .addTask)
        #expect(try DeepLink(url: #require(URL(string: "lockcast://unknown"))) == nil)
        // 作った URL は、同じ行き先として読み戻せる。
        #expect(DeepLink(url: DeepLink.focus.url) == .focus)
        #expect(DeepLink(url: DeepLink.addTask.url) == .addTask)
    }
}
