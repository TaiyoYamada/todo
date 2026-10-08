import ComposableArchitecture
import Domain
import Foundation

/// 「予定」の画面。目標とタスクの一覧。
@Reducer
struct PlanFeature {
    @ObservableState
    struct State: Equatable {
        @SharedReader(.board) var board

        /// 未完了のタスク。着手リミットが近い順。
        var openTasks: [TaskItem] {
            let world = board.world
            return world.openTasks.sorted { world.startLimit(of: $0) < world.startLimit(of: $1) }
        }

        /// 片づけたタスク。新しい順に、直近のものだけ。
        var closedTasks: [TaskItem] {
            let closed = board.world.tasks.filter { !$0.isOpen }
            let sorted = closed.sorted {
                ($0.completedAt ?? $0.withdrawnAt ?? .distantPast) > ($1.completedAt ?? $1.withdrawnAt ?? .distantPast)
            }
            return Array(sorted.prefix(20))
        }
    }

    enum Action {
        case addGoalTapped
        case addTaskTapped
        case goalTapped(Goal.ID)
        case taskTapped(TaskItem.ID)
        case completeTaskTapped(TaskItem.ID)
        case delegate(Route)
    }

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .addGoalTapped: .send(.delegate(.editGoal(nil)))
            case .addTaskTapped: .send(.delegate(.editTask(nil)))
            case let .goalTapped(id): .send(.delegate(.editGoal(id)))
            case let .taskTapped(id): .send(.delegate(.editTask(id)))
            case let .completeTaskTapped(id): .send(.delegate(.completeTask(id)))
            case .delegate: .none
            }
        }
    }
}
