import Domain
import SwiftUI

public extension Goal.Tint {
    /// 目標に付けた色。
    var color: Color {
        switch self {
        case .indigo: Color(red: 0.42, green: 0.45, blue: 1.00)
        case .blue: Color(red: 0.24, green: 0.62, blue: 1.00)
        case .teal: Color(red: 0.16, green: 0.80, blue: 0.80)
        case .green: Color(red: 0.26, green: 0.85, blue: 0.52)
        case .orange: Color(red: 1.00, green: 0.62, blue: 0.22)
        case .pink: Color(red: 1.00, green: 0.42, blue: 0.66)
        case .purple: Color(red: 0.72, green: 0.44, blue: 1.00)
        case .red: Color(red: 1.00, green: 0.38, blue: 0.36)
        }
    }
}

/// 画面全体の雰囲気を決める色の組。ロックの状態ごとに切り替える。
public struct Mood: Equatable, Sendable {
    /// 背景のグラデーションに使う色。暗い色から明るい色の順。
    public var backdrop: [Color]
    /// 主役の数字やボタンに使う色。
    public var accent: Color

    public init(backdrop: [Color], accent: Color) {
        self.backdrop = backdrop
        self.accent = accent
    }

    /// 余裕がたっぷりある。落ち着いた青緑。
    public static let calm = Self(
        backdrop: [
            Color(red: 0.02, green: 0.05, blue: 0.12),
            Color(red: 0.03, green: 0.16, blue: 0.30),
            Color(red: 0.05, green: 0.36, blue: 0.42),
            Color(red: 0.16, green: 0.24, blue: 0.56),
        ],
        accent: Color(red: 0.44, green: 0.94, blue: 0.86)
    )

    /// ロックが近い。注意を引く橙。
    public static let warning = Self(
        backdrop: [
            Color(red: 0.10, green: 0.04, blue: 0.03),
            Color(red: 0.36, green: 0.14, blue: 0.05),
            Color(red: 0.62, green: 0.30, blue: 0.06),
            Color(red: 0.34, green: 0.08, blue: 0.20),
        ],
        accent: Color(red: 1.00, green: 0.76, blue: 0.36)
    )

    /// ロック中。深い赤紫。
    public static let locked = Self(
        backdrop: [
            Color(red: 0.08, green: 0.02, blue: 0.06),
            Color(red: 0.30, green: 0.04, blue: 0.14),
            Color(red: 0.52, green: 0.08, blue: 0.16),
            Color(red: 0.22, green: 0.06, blue: 0.34),
        ],
        accent: Color(red: 1.00, green: 0.48, blue: 0.52)
    )

    /// 今日はもう自由。明るい緑。
    public static let free = Self(
        backdrop: [
            Color(red: 0.02, green: 0.08, blue: 0.08),
            Color(red: 0.04, green: 0.26, blue: 0.22),
            Color(red: 0.10, green: 0.46, blue: 0.34),
            Color(red: 0.06, green: 0.22, blue: 0.40),
        ],
        accent: Color(red: 0.56, green: 0.98, blue: 0.66)
    )

    /// 集中の計測中。目標の色を主役にする。
    public static func focus(_ tint: Goal.Tint) -> Self {
        Self(
            backdrop: [
                Color(red: 0.03, green: 0.03, blue: 0.08),
                tint.color.opacity(0.55),
                tint.color.opacity(0.85),
                Color(red: 0.10, green: 0.08, blue: 0.30),
            ],
            accent: tint.color
        )
    }
}

public extension EnvironmentValues {
    /// いまの画面の雰囲気。部品はここから色を取る。
    @Entry var mood: Mood = .calm
}
