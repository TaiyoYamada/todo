import Foundation

/// 「1日」と「1週間」の区切りを決める。
///
/// このアプリの1日は 0 時ではなく、設定した時刻(初期値は朝 4 時)に始まる。
/// 深夜 1 時にやった勉強を「今日の分」として数えるため。
public struct DayClock: Equatable, Sendable {
    public var calendar: Calendar
    public var dayStartHour: Int

    public init(calendar: Calendar, dayStartHour: Int) {
        self.calendar = calendar
        self.dayStartHour = dayStartHour
    }

    /// `date` を含む1日の開始時刻。
    public func dayStart(containing date: Date) -> Date {
        let shifted = calendar.date(byAdding: .hour, value: -dayStartHour, to: date) ?? date
        let midnight = calendar.startOfDay(for: shifted)
        return calendar.date(byAdding: .hour, value: dayStartHour, to: midnight) ?? midnight
    }

    /// `date` を含む1日の区間。終わりは次の日の開始で、区間には含まない。
    public func day(containing date: Date) -> DateInterval {
        let start = dayStart(containing: date)
        return DateInterval(start: start, end: dayStart(after: start))
    }

    /// 次の日の開始時刻。`dayStart` は1日の開始時刻であること。
    public func dayStart(after dayStart: Date) -> Date {
        offset(dayStart, days: 1)
    }

    public func offset(_ dayStart: Date, days: Int) -> Date {
        // 24 時間を足すのではなく暦の上で 1 日進める。夏時間の切り替え日でもずれないようにするため。
        let midnight = calendar.startOfDay(
            for: calendar.date(byAdding: .hour, value: -dayStartHour, to: dayStart) ?? dayStart
        )
        let moved = calendar.date(byAdding: .day, value: days, to: midnight) ?? midnight
        return calendar.date(byAdding: .hour, value: dayStartHour, to: moved) ?? moved
    }

    /// その日の曜日。深夜 1 時でも、前日の曜日として数える。
    public func weekday(ofDayStarting dayStart: Date) -> Weekday {
        let shifted = calendar.date(byAdding: .hour, value: -dayStartHour, to: dayStart) ?? dayStart
        return Weekday(rawValue: calendar.component(.weekday, from: shifted)) ?? .sunday
    }

    /// その日のうちの、指定した時刻。1日の開始より前の時刻は、翌日の暦の日付になる。
    public func time(minutesFromMidnight minutes: Int, inDayStarting dayStart: Date) -> Date {
        let shifted = calendar.date(byAdding: .hour, value: -dayStartHour, to: dayStart) ?? dayStart
        let midnight = calendar.startOfDay(for: shifted)
        let sameDate = calendar.date(byAdding: .minute, value: minutes, to: midnight) ?? midnight
        if sameDate >= dayStart { return sameDate }
        return calendar.date(byAdding: .day, value: 1, to: sameDate) ?? sameDate
    }

    /// `date` を含む週の区間。週は月曜の1日の開始から始まる。
    public func week(containing date: Date) -> DateInterval {
        let today = dayStart(containing: date)
        let weekday = weekday(ofDayStarting: today)
        let daysSinceMonday = (weekday.rawValue + 5) % 7
        let start = offset(today, days: -daysSinceMonday)
        return DateInterval(start: start, end: offset(start, days: 7))
    }
}
