import SwiftUI

extension View {
    /// ガラスのような面に載せる。カードやまとまりの背景に使う。
    public func glassCard(cornerRadius: CGFloat = 26, padding: CGFloat = 18) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }

    /// 見出し用の小さな文字。
    public func sectionLabelStyle() -> some View {
        self
            .font(.footnote.weight(.semibold))
            .textCase(.uppercase)
            .kerning(0.8)
            .foregroundStyle(.white.opacity(0.62))
    }
}

/// 画面でいちばん大事な操作のボタン。
public struct HeroButtonStyle: ButtonStyle {
    @Environment(\.mood) private var mood
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.black.opacity(0.86))
            .padding(.vertical, 17)
            .frame(maxWidth: .infinity)
            .background(mood.accent.gradient, in: .capsule)
            .shadow(color: mood.accent.opacity(0.45), radius: configuration.isPressed ? 6 : 18, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == HeroButtonStyle {
    public static var hero: HeroButtonStyle { HeroButtonStyle() }
}

/// 控えめな操作のボタン。
public struct QuietButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .background(.white.opacity(configuration.isPressed ? 0.22 : 0.12), in: .capsule)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == QuietButtonStyle {
    public static var quiet: QuietButtonStyle { QuietButtonStyle() }
}
