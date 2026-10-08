import ComposableArchitecture
import DatabaseClient
import Domain
import Foundation
import NotificationClient
import SharedCore
import ShieldClient

/// アプリの根。保存データを監視してロックの状態を計算し、各画面に配る。
@Reducer
struct AppFeature {
    @Reducer
    enum Destination {
        case focus(FocusFeature)
        case goalEditor(GoalEditorFeature)
        case taskEditor(TaskEditorFeature)
        case taskCompletion(TaskCompletionFeature)
        case settings(SettingsFeature)
    }

    enum Tab: Hashable, Sendable {
        case today, plan, insights
    }

    @ObservableState
    struct State: Equatable {
        @Shared(.board) var board
        var selectedTab = Tab.today
        var today = TodayFeature.State()
        var plan = PlanFeature.State()
        var insights = InsightsFeature.State()
        var onboarding: OnboardingFeature.State?
        @Presents var destination: Destination.State?
        /// 最後にスクリーンタイムの層へ伝えた指示。同じ内容を何度も送らないために覚えておく。
        var appliedPlan: ShieldPlan?
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case task
        case worldChanged(World)
        case tick
        case becameActive
        case openDeepLink(DeepLink)
        case today(TodayFeature.Action)
        case plan(PlanFeature.Action)
        case insights(InsightsFeature.Action)
        case onboarding(OnboardingFeature.Action)
        case destination(PresentationAction<Destination.Action>)
    }

    private enum CancelID { case observation, tick }

    /// 何も予定がなくても、この間隔では状態を計算し直す。表示中の「あと◯分」を古くしないため。
    static let refreshInterval: TimeInterval = 15

    @Dependency(\.calendar) var calendar
    @Dependency(\.continuousClock) var clock
    @Dependency(\.database) var database
    @Dependency(\.date.now) var now
    @Dependency(\.notifications) var notifications
    @Dependency(\.shield) var shield
    @Dependency(\.uuid) var uuid

    var body: some ReducerOf<Self> {
        BindingReducer()
        Scope(state: \.today, action: \.today) { TodayFeature() }
        Scope(state: \.plan, action: \.plan) { PlanFeature() }
        Scope(state: \.insights, action: \.insights) { InsightsFeature() }
        Reduce { state, action in
            switch action {
            case .task:
                return .run { send in
                    for await world in database.observeWorld() {
                        await send(.worldChanged(world))
                    }
                }
                .cancellable(id: CancelID.observation, cancelInFlight: true)

            case let .worldChanged(world):
                let isFirstLoad = !state.board.isLoaded
                state.$board.withLock {
                    $0.world = world
                    $0.isLoaded = true
                }
                refresh(&state)
                if isFirstLoad {
                    restore(&state)
                } else if !world.preferences.hasCompletedOnboarding, state.onboarding == nil {
                    // 設定から「はじめの説明をもう一度見る」を選んだとき。
                    state.destination = nil
                    state.onboarding = OnboardingFeature.State()
                }
                return .merge(scheduleTick(state), syncShield(&state))

            case .tick, .becameActive:
                guard state.board.isLoaded else { return .none }
                refresh(&state)
                return .merge(scheduleTick(state), syncShield(&state))

            case let .openDeepLink(link):
                // 初回設定の途中や、すでに何かを開いているときは、割り込まない。
                guard state.board.isLoaded, state.onboarding == nil, state.destination == nil else { return .none }
                switch link {
                case .focus:
                    let status = state.board.status
                    // ロックの理由になっている目標を優先し、なければ、まだ終えていない今日の分。
                    let lockedGoal = status.activeReasons.compactMap { reason -> Goal.ID? in
                        if case let .goal(id) = reason.source { id } else { nil }
                    }.first
                    guard let id = lockedGoal ?? status.goals.first(where: { !$0.isComplete })?.id else {
                        state.selectedTab = .today
                        return .none
                    }
                    open(.startFocus(id), &state)
                case .addTask:
                    open(.editTask(nil), &state)
                }
                return .none

            case let .today(.delegate(route)), let .plan(.delegate(route)):
                open(route, &state)
                return .none

            case let .destination(.presented(.taskEditor(.delegate(.complete(id))))):
                // 編集画面を閉じてから、完了の確認を開く。
                open(.completeTask(id), &state)
                return .none

            case .onboarding(.delegate(.finished)):
                state.onboarding = nil
                // 仕組みを理解してもらった直後に、通知の許可を求める。
                return .run { _ in _ = await notifications.requestAuthorization() }

            case .binding, .today, .plan, .insights, .onboarding, .destination:
                return .none
            }
        }
        .ifLet(\.onboarding, action: \.onboarding) { OnboardingFeature() }
        .ifLet(\.$destination, action: \.destination)
    }

    /// 保存データと現在時刻から、ロックの状態を計算し直す。
    private func refresh(_ state: inout State) {
        let now = now
        let engine = LockEngine(calendar: calendar)
        state.$board.withLock { $0.status = engine.status(world: $0.world, now: now) }
    }

    /// ロックの状態が変わっていれば、スクリーンタイムの層へ伝える。
    private func syncShield(_ state: inout State) -> Effect<Action> {
        let plan = ShieldPlan(status: state.board.status)
        guard plan != state.appliedPlan else { return .none }
        state.appliedPlan = plan
        let warnings = Self.warnings(for: state.board.status)
        return .run { [world = state.board.world] _ in
            await shield.apply(plan, world)
            await notifications.replaceAll(warnings)
        }
    }

    /// ロックの何分前に知らせるか。
    static let warningLead: TimeInterval = 30 * 60
    /// 一度に予約する、これからのロックの数。
    static let warningLimit = 8

    /// これから来るロックについて、前触れの通知と、始まったときの通知を作る。
    /// ロックされる前に動いてもらうのが狙いなので、前触れのほうが大事。
    static func warnings(for status: LockStatus) -> [LockNotification] {
        status.upcomingReasons.prefix(warningLimit).flatMap { reason -> [LockNotification] in
            let key = String(describing: reason.source)
            let started = LockNotification(
                id: "start-\(key)",
                title: String(localized: .notificationStartTitle),
                body: String(localized: .notificationStartBody(reason.title)),
                fireAt: reason.startsAt
            )
            let warnAt = reason.startsAt.addingTimeInterval(-warningLead)
            guard warnAt > status.now else { return [started] }
            let warning = LockNotification(
                id: "warn-\(key)",
                title: String(localized: .notificationWarnTitle),
                body: String(localized: .notificationWarnBody(reason.title)),
                fireAt: warnAt
            )
            return [warning, started]
        }
    }

    /// 起動直後に、前回の続きを戻す。
    private func restore(_ state: inout State) {
        let world = state.board.world
        if !world.preferences.hasCompletedOnboarding {
            state.onboarding = OnboardingFeature.State()
        } else if let focus = world.activeFocus, let goal = world.goal(id: focus.goalID) {
            // 計測中にアプリを閉じていた場合は、計測の画面に戻す。
            let progress = LockEngine(calendar: calendar).progress(of: goal, world: world, now: now)
            state.destination = .focus(
                FocusFeature.State(
                    goal: goal,
                    startedAt: focus.startedAt,
                    baseSeconds: progress.recordedSeconds,
                    isResumed: true
                )
            )
        }
    }

    /// 次に状態が変わる時刻(なければ一定の間隔)で、計算し直す。
    private func scheduleTick(_ state: State) -> Effect<Action> {
        let untilChange = state.board.status.nextChangeAt.map { $0.timeIntervalSince(now) }
        let delay = min(Self.refreshInterval, max(0.2, (untilChange ?? Self.refreshInterval) + 0.05))
        return .run { send in
            try await clock.sleep(for: .seconds(delay))
            await send(.tick)
        }
        .cancellable(id: CancelID.tick, cancelInFlight: true)
    }

    private func open(_ route: Route, _ state: inout State) {
        let world = state.board.world
        switch route {
        case let .startFocus(id):
            guard let goal = world.goal(id: id) else { return }
            let progress = LockEngine(calendar: calendar).progress(of: goal, world: world, now: now)
            state.destination = .focus(
                FocusFeature.State(goal: goal, startedAt: now, baseSeconds: progress.recordedSeconds)
            )

        case let .editGoal(id):
            if let id, let goal = world.goal(id: id) {
                state.destination = .goalEditor(GoalEditorFeature.State(goal: goal, isNew: false))
            } else {
                state.destination = .goalEditor(
                    GoalEditorFeature.State(goal: Goal(id: uuid(), title: "", createdAt: now), isNew: true)
                )
            }

        case let .editTask(id):
            if let id, let task = world.task(id: id) {
                state.destination = .taskEditor(TaskEditorFeature.State(task: task, isNew: false))
            } else {
                state.destination = .taskEditor(
                    TaskEditorFeature.State(
                        task: TaskItem(id: uuid(), title: "", dueAt: defaultDueDate(), createdAt: now),
                        isNew: true
                    )
                )
            }

        case let .completeTask(id):
            guard let task = world.task(id: id) else { return }
            state.destination = .taskCompletion(TaskCompletionFeature.State(task: task))

        case .openSettings:
            state.destination = .settings(SettingsFeature.State())
        }
    }

    /// 新しいタスクの締切の初期値。明日の 23:59。提出物の締切に多い時刻に合わせる。
    private func defaultDueDate() -> Date {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        return calendar.date(bySettingHour: 23, minute: 59, second: 0, of: tomorrow) ?? tomorrow
    }
}

extension AppFeature.Destination.State: Equatable {}
