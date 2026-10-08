import Foundation

/// ある1日のロックの見込み。週間予報の1日分。
public struct DayOutlook: Identifiable, Equatable, Sendable {
    public var dayStart: Date
    /// その日にロックの理由になる(なりうる)もの。時刻順。
    public var entries: [ForecastEntry]

    public var id: Date { dayStart }

    public init(dayStart: Date, entries: [ForecastEntry]) {
        self.dayStart = dayStart
        self.entries = entries
    }

    /// まだ片づいていないもの。
    public var pending: [ForecastEntry] { entries.filter { $0.state != .cleared } }

    /// その日の最初のロックの時刻。片づいたものは除く。
    public var firstLockAt: Date? { pending.map(\.at).min() }

    public var pendingTaskCount: Int {
        pending.filter { if case .task = $0.source { true } else { false } }.count
    }

    public var pendingGoalCount: Int { pending.count - pendingTaskCount }

    /// その日の荒れ具合。天気予報のように、ひと目で分かる段階にする。
    public var severity: Severity {
        if pending.isEmpty { return .clear }
        switch pendingTaskCount {
        case 0: return .routine
        case 1: return .deadline
        default: return .heavy
        }
    }

    public enum Severity: Equatable, Sendable {
        /// ロックの予定がない。
        case clear
        /// いつもの目標だけ。
        case routine
        /// 締切が1つある。
        case deadline
        /// 締切が重なっている。
        case heavy
    }
}

extension LockEngine {
    /// 今日から `days` 日ぶんの、ロックの見込み。
    ///
    /// 先の予定を自分で組まなくても、どの日が荒れそうかを先に見られるようにする。
    public func weekOutlook(world: World, now: Date, days: Int = 7) -> [DayOutlook] {
        let clock = DayClock(calendar: calendar, dayStartHour: world.preferences.dayStartHour)
        let status = status(world: world, now: now)
        let factor = world.estimateFactor

        return (0..<days).map { offset in
            let dayStart = clock.offset(status.today.start, days: offset)
            // 今日のぶんは、済んだものも含めた正確な内容がすでにある。
            guard offset > 0 else { return DayOutlook(dayStart: dayStart, entries: status.forecast) }

            let dayEnd = clock.dayStart(after: dayStart)
            let weekday = clock.weekday(ofDayStarting: dayStart)
            let goals = world.activeGoals
                .filter { $0.weekdays.contains(weekday) && $0.dailyMinutes > 0 && $0.createdAt < dayStart }
                .map { goal -> ForecastEntry in
                    let at: Date =
                        switch goal.lockStart {
                        case .dayStart: dayStart
                        case let .timeOfDay(minutes): clock.time(minutesFromMidnight: minutes, inDayStarting: dayStart)
                        }
                    return ForecastEntry(source: .goal(goal.id), title: goal.title, at: at, state: .upcoming)
                }
            let tasks = world.openTasks.compactMap { task -> ForecastEntry? in
                let at = task.startLimit(factor: factor)
                guard dayStart <= at, at < dayEnd else { return nil }
                return ForecastEntry(source: .task(task.id), title: task.title, at: at, state: .upcoming)
            }
            return DayOutlook(
                dayStart: dayStart,
                entries: (goals + tasks).sorted { ($0.at, $0.title) < ($1.at, $1.title) }
            )
        }
    }
}
