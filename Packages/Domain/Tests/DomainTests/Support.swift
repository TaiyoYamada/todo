import Foundation

@testable import Domain

/// テスト用の暦。東京時間のグレゴリオ暦に固定して、実行する場所で結果が変わらないようにする。
let tokyo: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    return calendar
}()

/// 2026年10月の日時を作る。10/9 は金曜日。
func date(_ day: Int, _ hour: Int = 0, _ minute: Int = 0, month: Int = 10, year: Int = 2026) -> Date {
    tokyo.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

func uuid(_ value: Int) -> UUID {
    UUID(uuidString: "00000000-0000-0000-0000-" + String(format: "%012d", value))!
}

extension Goal {
    /// 前日に作った目標。作った当日はロックしない規則を避けるため。
    static func fixture(
        _ id: Int = 1,
        title: String = "院試",
        dailyMinutes: Int = 30,
        weekdays: Set<Weekday> = Weekday.everyDay,
        lockStart: LockStart = .dayStart,
        createdAt: Date = date(8, 12)
    ) -> Goal {
        Goal(
            id: uuid(id),
            title: title,
            dailyMinutes: dailyMinutes,
            weekdays: weekdays,
            lockStart: lockStart,
            createdAt: createdAt
        )
    }
}

extension TaskItem {
    static func fixture(
        _ id: Int = 100,
        title: String = "レポート",
        dueAt: Date = date(9, 23, 59),
        estimateMinutes: Int = 120,
        completedAt: Date? = nil,
        withdrawnAt: Date? = nil
    ) -> TaskItem {
        TaskItem(
            id: uuid(id),
            title: title,
            dueAt: dueAt,
            estimateMinutes: estimateMinutes,
            completedAt: completedAt,
            withdrawnAt: withdrawnAt,
            createdAt: date(8, 12)
        )
    }
}

extension FocusSession {
    static func fixture(_ id: Int = 200, goal: Int = 1, startedAt: Date, minutes: Int) -> FocusSession {
        FocusSession(id: uuid(id), goalID: uuid(goal), startedAt: startedAt, seconds: minutes * 60)
    }
}
