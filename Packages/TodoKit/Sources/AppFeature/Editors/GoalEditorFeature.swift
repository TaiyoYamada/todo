import ComposableArchitecture
import DatabaseClient
import Domain
import Foundation

/// 目標の追加と編集。
@Reducer
struct GoalEditorFeature {
    @ObservableState
    struct State: Equatable {
        var goal: Goal
        let isNew: Bool

        var canSave: Bool {
            !goal.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !goal.weekdays.isEmpty
        }

        /// 「時刻を指定」で使う時刻(0 時からの分)。「朝から」に戻しても、選んだ時刻を覚えておく。
        var lockTimeMinutes = 20 * 60

        var locksAtTime: Bool {
            get { goal.lockStart != .dayStart }
            set { goal.lockStart = newValue ? .timeOfDay(minutes: lockTimeMinutes) : .dayStart }
        }

        init(goal: Goal, isNew: Bool) {
            self.goal = goal
            self.isNew = isNew
            if case let .timeOfDay(minutes) = goal.lockStart {
                lockTimeMinutes = minutes
            }
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case weekdayTapped(Weekday)
        case lockTimeChanged(minutes: Int)
        case saveTapped
        case deleteConfirmed
        case cancelTapped
    }

    static let minutesRange = 5 ... 240
    static let minutesStep = 5
    static let minutesPresets = [15, 30, 45, 60, 90]
    static let symbols = [
        "book.fill", "graduationcap.fill", "pencil.and.ruler.fill", "function", "character.book.closed.fill",
        "globe", "laptopcomputer", "dumbbell.fill", "figure.run", "music.note", "paintbrush.fill", "briefcase.fill",
    ]

    @Dependency(\.database) var database
    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case let .weekdayTapped(weekday):
                if state.goal.weekdays.contains(weekday) {
                    state.goal.weekdays.remove(weekday)
                } else {
                    state.goal.weekdays.insert(weekday)
                }
                return .none

            case let .lockTimeChanged(minutes):
                state.lockTimeMinutes = minutes
                state.goal.lockStart = .timeOfDay(minutes: minutes)
                return .none

            case .saveTapped:
                guard state.canSave else { return .none }
                var goal = state.goal
                goal.title = goal.title.trimmingCharacters(in: .whitespacesAndNewlines)
                return .run { [goal] _ in
                    try await database.saveGoal(goal)
                    await dismiss()
                }

            case .deleteConfirmed:
                return .run { [id = state.goal.id] _ in
                    try await database.deleteGoal(id)
                    await dismiss()
                }

            case .cancelTapped:
                return .run { _ in await dismiss() }
            }
        }
    }
}
