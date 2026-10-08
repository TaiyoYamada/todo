import Foundation

/// 締切のあるやること。
public struct TaskItem: Identifiable, Equatable, Hashable, Sendable, Codable {
    public var id: UUID
    public var title: String
    public var dueAt: Date
    public var estimateMinutes: Int
    public var completedAt: Date?
    /// 取り下げた時刻。やらないと決めたタスクはロックの理由から外れる。
    public var withdrawnAt: Date?
    public var createdAt: Date

    public init(
        id: UUID,
        title: String,
        dueAt: Date,
        estimateMinutes: Int = 60,
        completedAt: Date? = nil,
        withdrawnAt: Date? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.title = title
        self.dueAt = dueAt
        self.estimateMinutes = estimateMinutes
        self.completedAt = completedAt
        self.withdrawnAt = withdrawnAt
        self.createdAt = createdAt
    }

    /// まだ片づいていない(完了も取り下げもしていない)。
    public var isOpen: Bool { completedAt == nil && withdrawnAt == nil }

    /// これ以上遅らせると間に合わない時刻。
    public func startLimit(buffer: Preferences.Buffer) -> Date {
        dueAt.addingTimeInterval(-Double(estimateMinutes) * 60 * buffer.factor)
    }
}
