import Foundation

/// スクリーンタイムの層に渡す指示。ロックの状態から、必要なことだけを抜き出したもの。
///
/// アプリ本体はこれを見て、いまロックを掛けるかどうかと、次に見直す時刻を決める。
public struct ShieldPlan: Equatable, Sendable, Codable {
    /// いまロックを掛けるべきか。
    public var isLocked: Bool
    /// ロック画面に出す、いちばん先に片づけるものの名前。
    public var title: String?
    /// 目標の場合の、今日の分の残り(秒)。
    public var remainingSeconds: Int?
    /// これからロックが始まる時刻。近い順。アプリを閉じていても起こしてもらうための予約に使う。
    public var wakeTimes: [Date]

    /// 予約できる数には OS の上限(20)がある。毎日の繰り返しのぶんを残して、この数までにする。
    public static let wakeTimeLimit = 12

    public init(isLocked: Bool, title: String? = nil, remainingSeconds: Int? = nil, wakeTimes: [Date] = []) {
        self.isLocked = isLocked
        self.title = title
        self.remainingSeconds = remainingSeconds
        self.wakeTimes = wakeTimes
    }

    public init(status: LockStatus) {
        let primary = status.activeReasons.first
        var times = status.upcomingReasons.map(\.startsAt)
        // パスが切れる時刻にも見直す。ロックに戻すため。
        if case let .onPass(until) = status.phase {
            times.append(until)
        }
        self.init(
            isLocked: status.isLocked,
            title: primary?.title,
            remainingSeconds: primary?.remainingSeconds,
            wakeTimes: Array(Set(times).sorted().prefix(Self.wakeTimeLimit))
        )
    }
}
