import Foundation

/// 締切のあるやること。
public struct TaskItem: Identifiable, Equatable, Hashable, Sendable, Codable {
    public var id: UUID
    public var title: String
    public var dueAt: Date
    public var estimateMinutes: Int
    /// 着手リミットを、見積もりどおり(倍率なし)で計算する。
    /// 自動の前倒しが合わないタスクのために、本人が個別に切り替えられる。
    public var usesExactEstimate: Bool
    /// 取りかかった時刻。「始める」を押したときに入る。実際にかかった時間の目安に使う。
    public var startedAt: Date?
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
        usesExactEstimate: Bool = false,
        startedAt: Date? = nil,
        actualMinutes: Int? = nil,
        completedAt: Date? = nil,
        withdrawnAt: Date? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.title = title
        self.dueAt = dueAt
        self.estimateMinutes = estimateMinutes
        self.usesExactEstimate = usesExactEstimate
        self.startedAt = startedAt
        self.actualMinutes = actualMinutes
        self.completedAt = completedAt
        self.withdrawnAt = withdrawnAt
        self.createdAt = createdAt
    }

    /// まだ片づいていない(完了も取り下げもしていない)。
    public var isOpen: Bool { completedAt == nil && withdrawnAt == nil }

    /// 取りかかってから `now` までの時間(分)。5 分刻みに丸める。まだ取りかかっていなければ nil。
    ///
    /// 途中で休んだ時間も含むので、正確な作業時間ではない。完了のときの初期値として使い、本人が直せるようにする。
    public func elapsedMinutes(until now: Date) -> Int? {
        guard let startedAt else { return nil }
        let minutes = now.timeIntervalSince(startedAt) / 60
        return max(5, Int((minutes / 5).rounded()) * 5)
    }

    /// これ以上遅らせると間に合わない時刻。
    ///
    /// - Parameter factor: 見積もりに掛ける倍率。人は所要時間を短く見積もるので、1 より大きくする。
    ///   `usesExactEstimate` が有効なタスクには掛けない。
    public func startLimit(factor: Double) -> Date {
        dueAt.addingTimeInterval(-Double(estimateMinutes) * 60 * (usesExactEstimate ? 1 : factor))
    }
}
