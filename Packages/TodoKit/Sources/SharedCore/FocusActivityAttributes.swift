#if canImport(ActivityKit)
    import ActivityKit
    import Foundation

    /// 集中の計測を、ロック画面と Dynamic Island に出すための情報。
    ///
    /// アプリ本体(開始と終了)とウィジェットの拡張機能(表示)の両方が使うので、共有の場所に置く。
    public struct FocusActivityAttributes: ActivityAttributes {
        public struct ContentState: Codable, Hashable, Sendable {
            public var startedAt: Date
            /// 今日の分に達する時刻。すでに達していて、終わりのない計測なら nil。
            public var endsAt: Date?

            public init(startedAt: Date, endsAt: Date?) {
                self.startedAt = startedAt
                self.endsAt = endsAt
            }
        }

        public var goalTitle: String
        public var symbol: String
        /// `Goal.Tint` の rawValue。
        public var tint: String

        public init(goalTitle: String, symbol: String, tint: String) {
            self.goalTitle = goalTitle
            self.symbol = symbol
            self.tint = tint
        }
    }
#endif
