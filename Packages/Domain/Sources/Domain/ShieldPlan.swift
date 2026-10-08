import Foundation

/// スクリーンタイムの層に渡す指示。ロックの状態から、必要なことだけを抜き出したもの。
///
/// アプリ本体はこれを見て、いまロックを掛けるかどうかと、次に見直す時刻を決める。
public struct ShieldPlan: Equatable, Sendable, Codable {
    /// いまロックを掛けるべきか。
    public var isLocked: Bool
    /// ロック画面に出す、いちばん先に片づけるものの名前。
    public var title: String?
    /// これからロックが始まる時刻。近い順。アプリを閉じていても起こしてもらうための予約に使う。
    public var wakeTimes: [Date]

    /// 予約できる数には OS の上限(20)がある。毎日の繰り返しのぶんを残して、この数までにする。
    public static let wakeTimeLimit = 12

    /// 「残り何分」のように刻々と変わる値は、ここには入れない。
    /// 入れると、内容が変わるたびに予約をやり直すことになる。必要な側が、写しから自分で計算する。
    public init(isLocked: Bool, title: String? = nil, wakeTimes: [Date] = []) {
        self.isLocked = isLocked
        self.title = title
        self.wakeTimes = wakeTimes
    }

    /// - Parameter activeFocus: 計測中の集中。あれば、今日の分に達する時刻にも見直す。
    public init(status: LockStatus, activeFocus: ActiveFocus? = nil) {
        let primary = status.activeReasons.first
        var times = status.upcomingReasons.map(\.startsAt)
        // パスが切れる時刻にも見直す。ロックに戻すため。
        if case let .onPass(until) = status.phase {
            times.append(until)
        }
        // 計測が今日の分に達する時刻にも見直す。アプリを閉じて勉強していても、達した時点でロックを外すため。
        if let activeFocus,
           let progress = status.goals.first(where: { $0.id == activeFocus.goalID }),
           progress.remainingSeconds > 0
        {
            times.append(status.now.addingTimeInterval(Double(progress.remainingSeconds)))
        }
        self.init(
            isLocked: status.isLocked,
            title: primary?.title,
            wakeTimes: Array(Set(times).sorted().prefix(Self.wakeTimeLimit))
        )
    }
}
