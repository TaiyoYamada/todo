import ComposableArchitecture
import DatabaseClient
import Domain
import Foundation

/// 「今日」の画面。次のロックまでの余裕と、ロック予報を見せる。
@Reducer
struct TodayFeature {
    @ObservableState
    struct State: Equatable {
        @SharedReader(.board) var board

        var hero: Hero { Hero(status: board.status, world: board.world) }
    }

    enum Action {
        case startFocusTapped(Goal.ID)
        case goalTapped(Goal.ID)
        case taskTapped(TaskItem.ID)
        case completeTaskTapped(TaskItem.ID)
        case addGoalTapped
        case addTaskTapped
        case settingsTapped
        case usePassConfirmed
        case delegate(Route)
    }

    @Dependency(\.database) var database
    @Dependency(\.date.now) var now
    @Dependency(\.uuid) var uuid

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .startFocusTapped(id):
                return .send(.delegate(.startFocus(id)))

            case let .goalTapped(id):
                return .send(.delegate(.editGoal(id)))

            case let .taskTapped(id):
                return .send(.delegate(.editTask(id)))

            case let .completeTaskTapped(id):
                return .send(.delegate(.completeTask(id)))

            case .addGoalTapped:
                return .send(.delegate(.editGoal(nil)))

            case .addTaskTapped:
                return .send(.delegate(.editTask(nil)))

            case .settingsTapped:
                return .send(.delegate(.openSettings))

            case .usePassConfirmed:
                guard state.board.status.canUsePass else { return .none }
                let passUse = PassUse(id: uuid(), usedAt: now, minutes: state.board.world.preferences.passMinutes)
                return .run { _ in
                    try await database.addPassUse(passUse)
                }

            case .delegate:
                return .none
            }
        }
    }
}

/// 「今日」の画面の一番上に出す内容。ロックの状態から決まる。
enum Hero: Equatable {
    /// まだ目標もタスクもない。
    case empty
    /// ロック中。`primary` を片づければ外れる(ほかにも理由があれば `others` 件)。
    case locked(primary: LockReason, others: Int)
    /// パスで一時的に外れている。
    case onPass(until: Date, primary: LockReason)
    /// 今日のうちに次のロックが来る。
    case countdown(until: Date, reason: LockReason?)
    /// 今日はもうロックの予定がない。
    case freeToday(nextLockAt: Date?)

    init(status: LockStatus, world: World) {
        switch status.phase {
        case .locked:
            if let primary = status.activeReasons.first {
                self = .locked(primary: primary, others: status.activeReasons.count - 1)
            } else {
                self = .freeToday(nextLockAt: nil)
            }

        case let .onPass(until):
            if let primary = status.activeReasons.first {
                self = .onPass(until: until, primary: primary)
            } else {
                self = .freeToday(nextLockAt: nil)
            }

        case let .free(nextLockAt):
            if world.activeGoals.isEmpty, world.openTasks.isEmpty {
                self = .empty
            } else if let nextLockAt, nextLockAt < status.today.end {
                self = .countdown(until: nextLockAt, reason: status.upcomingReasons.first { $0.startsAt == nextLockAt })
            } else {
                self = .freeToday(nextLockAt: nextLockAt)
            }
        }
    }
}
