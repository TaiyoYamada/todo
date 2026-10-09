import Domain
import SwiftUI
import UIKit

/// 画面の作り方の流儀。見比べるために、いまは2つを切り替えられるようにしている。
public enum UIStyle: String, Sendable {
    /// 流れるグラデーションとガラスのカード(最初の版)。
    case aurora
    /// 単色、太い枠、沈むボタン、キャラクター。質感ではなく動きで見せる。
    case playful
}

public extension EnvironmentValues {
    @Entry var uiStyle: UIStyle = .aurora
}

/// 「面」と、その下に見える「縁」の色の組。縁を少しずらして見せることで、押せる厚みを出す。
public struct PlayfulTone: Equatable, Sendable {
    /// 面の色。
    public var face: Color
    /// 面の下にのぞく縁の色。面より暗い。
    public var edge: Color
    /// 面の上に載せる文字や記号の色。
    public var onFace: Color

    public init(face: Color, edge: Color, onFace: Color) {
        self.face = face
        self.edge = edge
        self.onFace = onFace
    }

    /// 1色から、縁と文字の色を作る。目標に付けた色などに使う。
    public init(base: Color) {
        self.init(face: base, edge: base.mix(with: .black, by: 0.24), onFace: .black.opacity(0.82))
    }
}

/// この流儀で使う色。グラデーション、ぼかし、発光は使わず、すべて単色で塗る。
public enum Playful {
    public static let background = Color(light: 0xFFFFFF, dark: 0x10161D)
    public static let surface = Color(light: 0xFFFFFF, dark: 0x17212B)
    /// 枠線と、カードの下の縁。
    public static let line = Color(light: 0xE1E7ED, dark: 0x2B3947)
    public static let text = Color(light: 0x1B2733, dark: 0xF1F5F9)
    public static let subtext = Color(light: 0x6B7A89, dark: 0x93A3B3)

    /// 余裕がある、自由。
    public static let mint = PlayfulTone(
        face: Color(hex: 0x2FD4B0), edge: Color(hex: 0x1FA58A), onFace: Color(hex: 0x06281F)
    )
    /// ロックが近い、パス中。
    public static let amber = PlayfulTone(
        face: Color(hex: 0xFFB020), edge: Color(hex: 0xD18A00), onFace: Color(hex: 0x3A2500)
    )
    /// ロック中。
    public static let coral = PlayfulTone(
        face: Color(hex: 0xFF5F63), edge: Color(hex: 0xD43C41), onFace: Color(hex: 0x3D0709)
    )
    /// まだ何もない。
    public static let sky = PlayfulTone(
        face: Color(hex: 0x4DB5FF), edge: Color(hex: 0x1E8FE0), onFace: Color(hex: 0x05243B)
    )
    /// 目立たせない操作。
    public static let neutral = PlayfulTone(face: surface, edge: line, onFace: text)
}

public extension Goal.Tint {
    /// 目標の色から作った、面と縁の組。
    var tone: PlayfulTone { PlayfulTone(base: color) }
}

extension Color {
    /// 0xRRGGBB の形で色を作る。
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// 明るい外観と暗い外観で切り替わる色。
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
    }
}
