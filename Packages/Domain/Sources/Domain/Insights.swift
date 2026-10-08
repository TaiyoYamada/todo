import Foundation

/// 振り返りの画面に出す集計。
public struct Insights: Equatable, Sendable {
    /// ある1日に、目標ごとにどれだけ進めたか。
    public struct Day: Identifiable, Equatable, Sendable {
        public struct Segment: Identifiable, Equatable, Sendable {
            public var goalID: Goal.ID
            public var seconds: Int
            public var id: Goal.ID { goalID }
        }

        public var dayStart: Date
        public var segments: [Segment]

        public var id: Date { dayStart }
        public var totalSeconds: Int { segments.reduce(0) { $0 + $1.seconds } }
    }

    /// 古い日から新しい日の順。最後が今日。
    public var days: [Day]
    public var thisWeekSeconds: Int
    public var lastWeekSeconds: Int
    /// 着手リミットより前に終えたタスクの数。ロックされる前に片づけた、という意味で一番良い結果。
    public var tasksBeforeLimit: Int
    /// 着手リミットを過ぎてから終えたタスクの数。
    public var tasksAfterLimit: Int
    public var tasksWithdrawn: Int
    public var passesThisWeek: Int
    public var calibration: EstimateCalibration

    /// 今日までに記録が1つでもあるか。
    public var hasAnyFocus: Bool { days.contains { $0.totalSeconds > 0 } }
}

public struct InsightsCalculator: Sendable {
    public var calendar: Calendar
    /// 日ごとの推移を何日ぶん出すか。
    public var dayCount: Int
    /// タスクの集計を何日前まで遡るか。
    public var taskWindowDays: Int

    public init(calendar: Calendar, dayCount: Int = 14, taskWindowDays: Int = 30) {
        self.calendar = calendar
        self.dayCount = dayCount
        self.taskWindowDays = taskWindowDays
    }

    public func insights(world: World, now: Date) -> Insights {
        let clock = DayClock(calendar: calendar, dayStartHour: world.preferences.dayStartHour)
        let today = clock.dayStart(containing: now)

        let days = (0..<dayCount).reversed().map { offset -> Insights.Day in
            let start = clock.offset(today, days: -offset)
            let end = clock.dayStart(after: start)
            var totals: [Goal.ID: Int] = [:]
            for session in world.sessions where start <= session.startedAt && session.startedAt < end {
                totals[session.goalID, default: 0] += session.seconds
            }
            // 目標の並び順にそろえる。グラフの積み重ねの順が日によって入れ替わらないように。
            let segments = world.goals.compactMap { goal in
                totals[goal.id].map { Insights.Day.Segment(goalID: goal.id, seconds: $0) }
            }
            return Insights.Day(dayStart: start, segments: segments)
        }

        let thisWeek = clock.week(containing: now)
        let lastWeek = DateInterval(start: clock.offset(thisWeek.start, days: -7), end: thisWeek.start)
        func seconds(in interval: DateInterval) -> Int {
            world.sessions
                .filter { interval.start <= $0.startedAt && $0.startedAt < interval.end }
                .reduce(0) { $0 + $1.seconds }
        }

        let windowStart = clock.offset(today, days: -taskWindowDays)
        let completed = world.tasks.filter { ($0.completedAt ?? .distantPast) >= windowStart }
        let factor = world.estimateFactor
        let beforeLimit = completed.filter {
            ($0.completedAt ?? .distantFuture) <= $0.startLimit(factor: factor)
        }

        return Insights(
            days: days,
            thisWeekSeconds: seconds(in: thisWeek),
            lastWeekSeconds: seconds(in: lastWeek),
            tasksBeforeLimit: beforeLimit.count,
            tasksAfterLimit: completed.count - beforeLimit.count,
            tasksWithdrawn: world.tasks.filter { ($0.withdrawnAt ?? .distantPast) >= windowStart }.count,
            passesThisWeek: world.passUses.filter { thisWeek.start <= $0.usedAt && $0.usedAt < thisWeek.end }.count,
            calibration: world.calibration
        )
    }
}
