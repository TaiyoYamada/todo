import Foundation

/// 時刻を表示用の文字列にする。
enum TimeText {
    /// 「21:59」「9:59 PM」。
    static func clock(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// 「今日 21:59」「明日 4:00」「10月12日(月) 18:00」。
    static func dayAndClock(_ date: Date, calendar: Calendar = .current) -> String {
        let day: String =
            if calendar.isDateInToday(date) {
                String(localized: .commonToday)
            } else if calendar.isDateInTomorrow(date) {
                String(localized: .commonTomorrow)
            } else {
                date.formatted(.dateTime.month().day().weekday(.abbreviated))
            }
        return "\(day) \(clock(date))"
    }
}
