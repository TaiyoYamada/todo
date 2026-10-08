import Foundation

/// 見積もりの癖。「実際にかかった時間 ÷ 見積もり」の傾向から、着手リミットを前倒しする倍率を決める。
///
/// 人は所要時間を短く見積もる(計画錯誤)。見積もりどおりの時刻にロックしても間に合わないので、
/// 本人の実績から倍率を学び、黙って前倒しする。
public struct EstimateCalibration: Equatable, Sendable {
    /// 見積もりに掛ける倍率。
    public var factor: Double
    /// 倍率の根拠になった、完了済みタスクの数。
    public var sampleCount: Int

    /// 実績が足りないうちに使う倍率。一般に見積もりは 1.5 倍前後かかるとされる。
    public static let fallbackFactor = 1.5
    /// 実績から倍率を決めるのに必要な、最低限の数。
    public static let minimumSamples = 3
    /// 直近の何件を見るか。古い癖に引きずられないように絞る。
    public static let window = 10
    /// 倍率の範囲。1 未満(見積もりより早く終わる人)でも、前倒しをやめるだけで後ろ倒しはしない。
    public static let factorRange = 1.0 ... 3.0

    public init(factor: Double, sampleCount: Int) {
        self.factor = factor
        self.sampleCount = sampleCount
    }

    public init(tasks: [TaskItem]) {
        let ratios = tasks
            .filter { $0.completedAt != nil && $0.actualMinutes != nil && $0.estimateMinutes > 0 }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            .prefix(Self.window)
            .map { Double($0.actualMinutes ?? 0) / Double($0.estimateMinutes) }
            .sorted()

        sampleCount = ratios.count
        guard ratios.count >= Self.minimumSamples else {
            factor = Self.fallbackFactor
            return
        }
        // 平均ではなく中央値を使う。1回だけ大きく外したタスクに振り回されないため。
        let middle = ratios.count / 2
        let median = ratios.count.isMultiple(of: 2) ? (ratios[middle - 1] + ratios[middle]) / 2 : ratios[middle]
        factor = min(max(median, Self.factorRange.lowerBound), Self.factorRange.upperBound)
    }

    /// 実績から倍率を決められているか。
    public var isLearned: Bool { sampleCount >= Self.minimumSamples }
}
