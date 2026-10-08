import Foundation

/// 目標を進めた1回分の記録。
public struct FocusSession: Identifiable, Equatable, Hashable, Sendable, Codable {
    public var id: UUID
    public var goalID: Goal.ID
    public var startedAt: Date
    public var seconds: Int

    public init(id: UUID, goalID: Goal.ID, startedAt: Date, seconds: Int) {
        self.id = id
        self.goalID = goalID
        self.startedAt = startedAt
        self.seconds = seconds
    }

    public var endedAt: Date { startedAt.addingTimeInterval(Double(seconds)) }
}

/// 計測中の集中。アプリを閉じても続くように保存しておく。
public struct ActiveFocus: Equatable, Hashable, Sendable, Codable {
    public var goalID: Goal.ID
    public var startedAt: Date

    public init(goalID: Goal.ID, startedAt: Date) {
        self.goalID = goalID
        self.startedAt = startedAt
    }
}

/// パス(非常口)を使った記録。
public struct PassUse: Identifiable, Equatable, Hashable, Sendable, Codable {
    public var id: UUID
    public var usedAt: Date
    public var minutes: Int

    public init(id: UUID, usedAt: Date, minutes: Int) {
        self.id = id
        self.usedAt = usedAt
        self.minutes = minutes
    }

    public var endsAt: Date { usedAt.addingTimeInterval(Double(minutes) * 60) }
}
