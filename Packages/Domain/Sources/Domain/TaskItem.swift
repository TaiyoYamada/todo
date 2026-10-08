import Foundation

/// 締切のあるやること。
public struct TaskItem: Identifiable, Equatable, Hashable, Sendable, Codable {
    public var id: UUID
    public var title: String
    public var dueAt: Date
    public var estimateMinutes: Int
    /// 実際にかかった時間。完了のときに本人が答える。見積もりの癖を学ぶのに使う。
    public var actualMinutes: Int?
    public var completedAt: Date?
    /// 取り下げた時刻。やらないと決めたタスクはロックの理由から外れる。
    public var withdrawnAt: Date?
    public var createdAt: Date

    public init(
        id: UUID,
        title: String,
        dueAt: Date,
        estimateMinutes: Int = 60,
        actualMinutes: Int? = nil,
        completedAt: Date? = nil,
        withdrawnAt: Date? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.title = title
        self.dueAt = dueAt
        self.estimateMinutes = estimateMinutes
        self.actualMinutes = actualMinutes
        self.completedAt = completedAt
        self.withdrawnAt = withdrawnAt
        self.createdAt = createdAt
    }

    /// まだ片づいていない(完了も取り下げもしていない)。
    public var isOpen: Bool { completedAt == nil && withdrawnAt == nil }

    /// これ以上遅らせると間に合わない時刻。
    ///
    /// - Parameter factor: 見積もりに掛ける倍率。人は所要時間を短く見積もるので、1 より大きくする。
    public func startLimit(factor: Double) -> Date {
        dueAt.addingTimeInterval(-Double(estimateMinutes) * 60 * factor)
    }
}
