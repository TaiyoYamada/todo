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

    // 時刻は「何時間後」ではなく「その日の何時」として求める。
    // 夏時間の切り替え日は1日が 23 時間や 25 時間になるので、時間を足し引きすると1時間ずれる。

    /// `date` を含む1日の開始時刻。
    public func dayStart(containing date: Date) -> Date {
        let sameDate = startHour(onCalendarDayOf: date)
        if sameDate <= date { return sameDate }
        // まだ今日の開始時刻になっていない(深夜)。前の暦の日に始まった1日に含まれる。
        let previous = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date)) ?? date
        return startHour(onCalendarDayOf: previous)
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

    /// `days` 日だけ前後にずらした日の、開始時刻。`dayStart` は1日の開始時刻であること。
    public func offset(_ dayStart: Date, days: Int) -> Date {
        let midnight = calendar.startOfDay(for: dayStart)
        let moved = calendar.date(byAdding: .day, value: days, to: midnight) ?? midnight
        return startHour(onCalendarDayOf: moved)
    }

    /// その日の曜日。深夜 1 時でも、前日の曜日として数える。`dayStart` は1日の開始時刻であること。
    public func weekday(ofDayStarting dayStart: Date) -> Weekday {
        Weekday(rawValue: calendar.component(.weekday, from: dayStart)) ?? .sunday
    }

    /// その日のうちの、指定した時刻。1日の開始より前の時刻は、翌日の暦の日付になる。
    public func time(minutesFromMidnight minutes: Int, inDayStarting dayStart: Date) -> Date {
        let sameDate = time(minutes, onCalendarDayOf: dayStart)
        if sameDate >= dayStart { return sameDate }
        let next = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: dayStart)) ?? dayStart
        return time(minutes, onCalendarDayOf: next)
    }

    private func startHour(onCalendarDayOf date: Date) -> Date {
        time(dayStartHour * 60, onCalendarDayOf: date)
    }

    /// `date` と同じ暦の日の、指定した時刻(0 時からの分)。
    private func time(_ minutes: Int, onCalendarDayOf date: Date) -> Date {
        let midnight = calendar.startOfDay(for: date)
        // 切り替えで存在しない時刻(2:30 など)は、その次に来る時刻になる。
        return calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: midnight) ?? midnight
    }

    /// `date` を含む週の区間。週は月曜の1日の開始から始まる。
    public func week(containing date: Date) -> DateInterval {
        let today = dayStart(containing: date)
        let weekday = weekday(ofDayStarting: today)
        let daysSinceMonday = (weekday.rawValue + 5) % 7
        let start = offset(today, days: -daysSinceMonday)
        return DateInterval(start: start, end: offset(start, days: 7))
    }

    /// `start` から `end` までの時間を、1日の区切りで分ける。
    ///
    /// 記録は「始めた日」のぶんとして数える。区切りをまたいだ計測を1つの記録にすると、
    /// またいだあとのぶんが前の日に入ってしまい、今日の分から消える。
    public func split(from start: Date, to end: Date) -> [DateInterval] {
        guard start < end else { return [] }
        var pieces: [DateInterval] = []
        var cursor = start
        while cursor < end {
            let boundary = day(containing: cursor).end
            let pieceEnd = min(boundary, end)
            pieces.append(DateInterval(start: cursor, end: pieceEnd))
            cursor = pieceEnd
        }
        return pieces
    }
}
