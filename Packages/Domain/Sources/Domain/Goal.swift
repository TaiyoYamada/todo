import Foundation

/// 締切が遠い大事なこと。「1日の量」と「やる曜日」を持つ。
public struct Goal: Identifiable, Equatable, Hashable, Sendable, Codable {
    public var id: UUID
    public var title: String
    /// SF Symbols の名前。
    public var symbol: String
    public var tint: Tint
    public var dailyMinutes: Int
    public var weekdays: Set<Weekday>
    public var lockStart: LockStart
    public var isArchived: Bool
    public var createdAt: Date

    public init(
        id: UUID,
        title: String,
        symbol: String = "book.fill",
        tint: Tint = .indigo,
        dailyMinutes: Int = 30,
        weekdays: Set<Weekday> = Weekday.everyDay,
        lockStart: LockStart = .dayStart,
        isArchived: Bool = false,
        createdAt: Date
    ) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.tint = tint
        self.dailyMinutes = dailyMinutes
        self.weekdays = weekdays
        self.lockStart = lockStart
        self.isArchived = isArchived
        self.createdAt = createdAt
    }

    public var dailySeconds: Int { dailyMinutes * 60 }
}

extension Goal {
    /// その日のうち、いつからロックの理由になるか。
    public enum LockStart: Equatable, Hashable, Sendable, Codable {
        /// 1日の開始から。
        case dayStart
        /// 指定した時刻から。値は 0 時からの分(0..<1440)。
        case timeOfDay(minutes: Int)
    }

    /// 目標に付ける色。実際の色は DesignSystem が決める。
    public enum Tint: String, CaseIterable, Sendable, Codable {
        case indigo, blue, teal, green, orange, pink, purple, red
    }
}

/// 曜日。値は `Calendar` の weekday と同じ(1 が日曜)。
public enum Weekday: Int, CaseIterable, Hashable, Sendable, Codable, Comparable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    public static let everyDay = Set(allCases)
    public static let weekdaysOnly: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
