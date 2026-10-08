import Foundation

/// 利用者が決める設定。
public struct Preferences: Equatable, Sendable, Codable {
    /// 1日が切り替わる時刻(時)。初期値の 4 は、夜更かしした深夜を前日として扱うため。
    public var dayStartHour: Int
    public var buffer: Buffer
    public var weeklyPassLimit: Int
    public var passMinutes: Int
    public var hasCompletedOnboarding: Bool

    public init(
        dayStartHour: Int = 4,
        buffer: Buffer = .none,
        weeklyPassLimit: Int = 2,
        passMinutes: Int = 15,
        hasCompletedOnboarding: Bool = false
    ) {
        self.dayStartHour = dayStartHour
        self.buffer = buffer
        self.weeklyPassLimit = weeklyPassLimit
        self.passMinutes = passMinutes
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }

    /// 着手リミットに持たせる余裕。見積もりが甘い人は大きくする。
    public enum Buffer: String, CaseIterable, Sendable, Codable {
        case none, quarter, half

        public var factor: Double {
            switch self {
            case .none: 1.0
            case .quarter: 1.25
            case .half: 1.5
            }
        }
    }

    /// 保存済みの JSON に項目が欠けていても読めるようにする。
    /// 設定を足すたびに、古いデータが読めなくなるのを防ぐ。
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Preferences()
        dayStartHour = try container.decodeIfPresent(Int.self, forKey: .dayStartHour) ?? defaults.dayStartHour
        buffer = try container.decodeIfPresent(Buffer.self, forKey: .buffer) ?? defaults.buffer
        weeklyPassLimit = try container.decodeIfPresent(Int.self, forKey: .weeklyPassLimit) ?? defaults.weeklyPassLimit
        passMinutes = try container.decodeIfPresent(Int.self, forKey: .passMinutes) ?? defaults.passMinutes
        hasCompletedOnboarding =
            try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? defaults.hasCompletedOnboarding
    }

    public static let weeklyPassLimitRange = 0...5
    public static let dayStartHourRange = 0...8
}
