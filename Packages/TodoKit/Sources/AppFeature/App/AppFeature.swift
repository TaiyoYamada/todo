import ComposableArchitecture
import DatabaseClient
import Domain
import Foundation
import NotificationClient
import SharedCore
import ShieldClient
import SnapshotClient

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
        /// 保存データを読み終える前に届いた、外からの依頼。読み終えたら開く。
        var pendingDeepLink: DeepLink?
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

    private enum CancelID { case observation, tick, sync }

    /// 何も予定がなくても、この間隔では状態を計算し直す。表示中の「あと◯分」を古くしないため。
    static let refreshInterval: TimeInterval = 15

    @Dependency(\.calendar) var calendar
    @Dependency(\.continuousClock) var clock
    @Dependency(\.database) var database
    @Dependency(\.date.now) var now
    @Dependency(\.notifications) var notifications
    @Dependency(\.shield) var shield
    @Dependency(\.snapshot) var snapshot
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
                let hadCompletedOnboarding = state.board.world.preferences.hasCompletedOnboarding
                state.$board.withLock {
                    $0.world = world
                    $0.isLoaded = true
                }
                refresh(&state)
                if isFirstLoad {
                    restore(&state)
                    if let link = state.pendingDeepLink {
                        state.pendingDeepLink = nil
                        handle(link, &state)
                    }
                } else if hadCompletedOnboarding, !world.preferences.hasCompletedOnboarding, state.onboarding == nil {
                    // 設定から「はじめの説明をもう一度見る」を選んだとき。
                    // 「済み」から「まだ」に変わった瞬間だけを見る。初回設定の最後は書き込みが2回あり、
                    // その途中の「まだ」を見て開き直してしまうのを防ぐ。
                    state.destination = nil
                    state.onboarding = OnboardingFeature.State()
                }
                return .merge(scheduleTick(state), syncOutside(&state, worldChanged: true))

            case .tick, .becameActive:
                guard state.board.isLoaded else { return .none }
                refresh(&state)
                return .merge(scheduleTick(state), syncOutside(&state, worldChanged: false))

            case let .openDeepLink(link):
                // アプリが起動していない状態から開かれると、保存データを読み終える前に届く。覚えておいて、あとで開く。
                guard state.board.isLoaded else {
                    state.pendingDeepLink = link
                    return .none
                }
                handle(link, &state)
                return .none

            case let .today(.delegate(route)), let .plan(.delegate(route)):
                open(route, &state)
                return .none

            case let .destination(.presented(.taskEditor(.delegate(.complete(task))))):
                // 編集画面を閉じてから、完了の確認を開く。編集中の内容をそのまま引き継ぐ。
                state.destination = .taskCompletion(
                    TaskCompletionFeature.State(task: task, measuredMinutes: task.elapsedMinutes(until: now))
                )
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

    /// アプリの外(ウィジェット、スクリーンタイム、通知)へ、いまの状況を伝える。
    ///
    /// 保存データが変わったときは必ず伝える。ロックの状態が同じでも、予約すべき時刻が変わっていることがあるため
    /// (たとえば、今日作った目標は今日はロックしないが、明日の朝の予約は要る)。
    /// 時間の経過だけのときは、ロックの状態が変わった場合に限る。
    private func syncOutside(_ state: inout State, worldChanged: Bool) -> Effect<Action> {
        let plan = ShieldPlan(status: state.board.status, activeFocus: state.board.world.activeFocus)
        guard worldChanged || plan != state.appliedPlan else { return .none }
        state.appliedPlan = plan
        let warnings = Self.warnings(for: state.board.status)
        return .run { [world = state.board.world] _ in
            // 写しを先に書く。スクリーンタイムの拡張機能が、予約の時刻に最新の状況で判定できるように。
            await snapshot.save(world)
            // 取り消されても、呼び出しの途中で勝手に止まりはしない。次へ進む前に、自分で確かめる。
            guard !Task.isCancelled else { return }
            await shield.apply(plan, world)
            guard !Task.isCancelled else { return }
            await notifications.replaceAll(warnings)
        }
        // 続けて変更が来たら、古いほうは途中でやめる。古い指示があとから適用されて、新しい状態を上書きするのを防ぐ。
        .cancellable(id: CancelID.sync, cancelInFlight: true)
    }

    /// アプリの外からの依頼に応える。
    private func handle(_ link: DeepLink, _ state: inout State) {
        // 初回設定の途中や、すでに何かを開いているときは、割り込まない。
        guard state.onboarding == nil, state.destination == nil else { return }
        switch link {
        case .focus:
            let status = state.board.status
            // ロックの理由になっている目標を優先し、なければ、まだ終えていない今日の分。
            let lockedGoal = status.activeReasons.compactMap { reason -> Goal.ID? in
                if case let .goal(id) = reason.source { id } else { nil }
            }.first
            guard let id = lockedGoal ?? status.goals.first(where: { !$0.isComplete })?.id else {
                state.selectedTab = .today
                return
            }
            open(.startFocus(id), &state)
        case .addTask:
            open(.editTask(nil), &state)
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
            state.destination = .taskCompletion(
                TaskCompletionFeature.State(task: task, measuredMinutes: task.elapsedMinutes(until: now))
            )

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
