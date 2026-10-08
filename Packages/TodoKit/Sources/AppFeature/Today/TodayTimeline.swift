import Domain
import Foundation

/// 今日の画面に並べる1行。目標の今日の分か、今日のうちに着手リミットが来るタスク。
///
/// 「ロック予報」と「今日の分」は同じものを別の角度から見せていたので、時刻順の1本にまとめる。
struct TimelineItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case goal(GoalProgress)
        case task(TaskItem)
    }

    enum State: Equatable {
        /// もう片づいた。
        case cleared
        /// いまロックの理由になっている。
        case active
        /// これからロックの理由になる。
        case upcoming
        /// 今日はロックの理由にならない(目標を作った当日)。
        case optional
    }

    var source: LockReason.Source
    var kind: Kind
    /// ロックの理由になる時刻。`optional` のときは nil。
    var at: Date?
    var state: State

    var id: LockReason.Source { source }

    var title: String {
        switch kind {
        case let .goal(progress): progress.goal.title
        case let .task(task): task.title
        }
    }
}

enum TodayTimeline {
    /// 今日の行を、見る順に並べる。
    ///
    /// まだ片づいていないものを時刻順に上へ、片づいたものを下へ。
    /// 次に危ないものがいつも一番上に来るようにする。
    static func items(status: LockStatus, world: World) -> [TimelineItem] {
        let goals = status.goals.map { progress -> TimelineItem in
            let state: TimelineItem.State =
                if progress.isComplete {
                    .cleared
                } else if let at = progress.lockStartsAt {
                    at <= status.now ? .active : .upcoming
                } else {
                    .optional
                }
            return TimelineItem(source: .goal(progress.id), kind: .goal(progress), at: progress.lockStartsAt, state: state)
        }

        let tasks = status.forecast.compactMap { entry -> TimelineItem? in
            guard case let .task(id) = entry.source, let task = world.task(id: id) else { return nil }
            let state: TimelineItem.State =
                switch entry.state {
                case .cleared: .cleared
                case .active: .active
                case .upcoming: .upcoming
                }
            return TimelineItem(source: entry.source, kind: .task(task), at: entry.at, state: state)
        }

        return (goals + tasks).sorted { lhs, rhs in
            let lhsCleared = lhs.state == .cleared
            let rhsCleared = rhs.state == .cleared
            if lhsCleared != rhsCleared { return !lhsCleared }
            return (lhs.at ?? .distantFuture, lhs.title) < (rhs.at ?? .distantFuture, rhs.title)
        }
    }
}
