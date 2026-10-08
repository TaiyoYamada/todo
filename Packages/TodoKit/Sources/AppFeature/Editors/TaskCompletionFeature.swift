import ComposableArchitecture
import DatabaseClient
import Domain
import Foundation

/// タスクを完了にする。そのとき、実際にかかった時間を聞く。
///
/// 完了が自己申告である以上、押すだけで外れるのは避けられない。
/// そこで1つだけ質問を挟み、その答えを見積もりの癖の学習に使う。
@Reducer
struct TaskCompletionFeature {
    @ObservableState
    struct State: Equatable {
        let task: TaskItem
        var actualMinutes: Int
        /// 「始める」を押してから完了までの時間。押していなければ nil。
        let measuredMinutes: Int?

        /// - Parameter measuredMinutes: 取りかかってからの時間。分かっていれば、それを初期値にする。
        init(task: TaskItem, measuredMinutes: Int? = nil) {
            self.task = task
            self.measuredMinutes = measuredMinutes
            actualMinutes = measuredMinutes ?? task.estimateMinutes
        }

        /// 見積もりを基準にした選択肢。半分、ちょうど、1.5 倍、2 倍、3 倍。測った時間があれば、それも入れる。
        var options: [Int] {
            let estimate = task.estimateMinutes
            var raw = [estimate / 2, estimate, estimate * 3 / 2, estimate * 2, estimate * 3]
            if let measuredMinutes {
                raw.append(measuredMinutes)
            }
            // 5 分刻みに丸め、重複を除いて、短い順に並べる。
            return Set(raw.map { max(5, Int((Double($0) / 5).rounded()) * 5) }).sorted()
        }
    }

    enum Action {
        case optionTapped(Int)
        case confirmTapped
        case cancelTapped
    }

    @Dependency(\.database) var database
    @Dependency(\.date.now) var now
    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .optionTapped(minutes):
                state.actualMinutes = minutes
                return .none

            case .confirmTapped:
                var task = state.task
                task.completedAt = now
                task.actualMinutes = state.actualMinutes
                return .run { [task] _ in
                    try await database.saveTask(task)
                    await dismiss()
                }

            case .cancelTapped:
                return .run { _ in await dismiss() }
            }
        }
    }
}
