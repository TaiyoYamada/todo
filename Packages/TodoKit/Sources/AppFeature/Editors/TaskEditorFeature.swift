import ComposableArchitecture
import DatabaseClient
import Domain
import Foundation

/// タスクの追加と編集。
@Reducer
struct TaskEditorFeature {
    @ObservableState
    struct State: Equatable {
        @SharedReader(.board) var board
        var task: TaskItem
        let isNew: Bool
        /// 名前の欄に書かれた文から読み取れた、締切と所要時間。反映するかどうかは本人が決める。
        var suggestion: QuickAdd?

        var canSave: Bool {
            !task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        /// この内容で保存したときの着手リミット。
        var startLimit: Date { board.world.startLimit(of: task) }

        /// 保存した時点で、もう着手リミットを過ぎている。
        var locksImmediately: Bool { task.isOpen && startLimit <= board.status.now }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case applySuggestionTapped
        case saveTapped
        case completeTapped
        case withdrawConfirmed
        case reopenTapped
        case deleteConfirmed
        case cancelTapped
        case delegate(Delegate)

        enum Delegate: Equatable {
            case complete(TaskItem.ID)
        }
    }

    static let estimateRange = 5...600
    static let estimateStep = 5
    static let estimatePresets = [15, 30, 60, 120, 180]

    @Dependency(\.calendar) var calendar
    @Dependency(\.database) var database
    @Dependency(\.date.now) var now
    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.task.title):
                // 「金曜までにレポート 2時間」のように書かれたら、締切と所要時間を読み取って提案する。
                let parsed = QuickAddParser(calendar: calendar).parse(state.task.title, now: now)
                state.suggestion = parsed.hasDetails && !parsed.title.isEmpty ? parsed : nil
                return .none

            case .binding, .delegate:
                return .none

            case .applySuggestionTapped:
                guard let suggestion = state.suggestion else { return .none }
                state.task.title = suggestion.title
                if let dueAt = suggestion.dueAt {
                    state.task.dueAt = dueAt
                }
                if let minutes = suggestion.estimateMinutes {
                    // 選べる範囲と刻みに合わせる。
                    let stepped = Int((Double(minutes) / Double(Self.estimateStep)).rounded()) * Self.estimateStep
                    state.task.estimateMinutes = min(max(stepped, Self.estimateRange.lowerBound), Self.estimateRange.upperBound)
                }
                state.suggestion = nil
                return .none

            case .saveTapped:
                guard state.canSave else { return .none }
                return save(state.task)

            case .completeTapped:
                // 実際にかかった時間を聞く画面は、親が開く。
                return .send(.delegate(.complete(state.task.id)))

            case .withdrawConfirmed:
                var task = state.task
                task.withdrawnAt = now
                return save(task)

            case .reopenTapped:
                var task = state.task
                task.completedAt = nil
                task.actualMinutes = nil
                task.withdrawnAt = nil
                return save(task)

            case .deleteConfirmed:
                return .run { [id = state.task.id] _ in
                    try await database.deleteTask(id)
                    await dismiss()
                }

            case .cancelTapped:
                return .run { _ in await dismiss() }
            }
        }
    }

    private func save(_ task: TaskItem) -> Effect<Action> {
        var task = task
        task.title = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return .run { [task] _ in
            try await database.saveTask(task)
            await dismiss()
        }
    }
}
