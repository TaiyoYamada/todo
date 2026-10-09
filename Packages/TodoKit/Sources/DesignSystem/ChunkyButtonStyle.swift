import SwiftUI

/// 厚みのある、押すと沈むボタン。
///
/// 影やグラデーションは使わない。面の下に縁の色をずらして置き、押したときに面をその分だけ下げる。
/// 指で物を押し込む感じを、形のずれだけで出す。
public struct ChunkyButtonStyle: ButtonStyle {
    private let tone: PlayfulTone
    private let depth: CGFloat
    private let cornerRadius: CGFloat

    @Environment(\.isEnabled) private var isEnabled

    public init(tone: PlayfulTone, depth: CGFloat = 5, cornerRadius: CGFloat = 16) {
        self.tone = tone
        self.depth = depth
        self.cornerRadius = cornerRadius
    }

    public func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .heavy))
            .foregroundStyle(tone.onFace)
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .background(tone.face, in: shape)
            .overlay { shape.strokeBorder(tone.edge, lineWidth: tone == Playful.neutral ? 2 : 0) }
            .offset(y: configuration.isPressed ? depth : 0)
            .background(alignment: .top) { shape.fill(tone.edge).offset(y: depth) }
            .padding(.bottom, depth)
            .opacity(isEnabled ? 1 : 0.5)
            .animation(.spring(duration: 0.14, bounce: 0.35), value: configuration.isPressed)
    }
}

/// 丸い小さなボタン。行の端に置く、その場の操作に使う。
public struct ChunkyIconButtonStyle: ButtonStyle {
    private let tone: PlayfulTone
    private let size: CGFloat
    private let depth: CGFloat

    public init(tone: PlayfulTone, size: CGFloat = 44, depth: CGFloat = 4) {
        self.tone = tone
        self.size = size
        self.depth = depth
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .rounded, weight: .heavy))
            .foregroundStyle(tone.onFace)
            .frame(width: size, height: size)
            .background(tone.face, in: .circle)
            .overlay { Circle().strokeBorder(tone.edge, lineWidth: tone == Playful.neutral ? 2 : 0) }
            .offset(y: configuration.isPressed ? depth : 0)
            .background(alignment: .top) { Circle().fill(tone.edge).offset(y: depth) }
            .padding(.bottom, depth)
            .animation(.spring(duration: 0.14, bounce: 0.35), value: configuration.isPressed)
    }
}

/// 画面でいちばん大事な操作のボタン。色は、いまの画面の主役の色(`\.tone`)に合わせる。
public struct ChunkyPrimaryButtonStyle: ButtonStyle {
    @Environment(\.tone) private var tone

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        ChunkyButtonStyle(tone: tone).makeBody(configuration: configuration)
    }
}

public extension ButtonStyle where Self == ChunkyPrimaryButtonStyle {
    /// いちばん大事な操作。
    static var chunkyPrimary: ChunkyPrimaryButtonStyle { ChunkyPrimaryButtonStyle() }
}

public extension ButtonStyle where Self == ChunkyButtonStyle {
    /// 控えめな操作。
    static var chunkySecondary: ChunkyButtonStyle { ChunkyButtonStyle(tone: Playful.neutral) }

    static func chunky(_ tone: PlayfulTone) -> ChunkyButtonStyle { ChunkyButtonStyle(tone: tone) }
}

public extension ButtonStyle where Self == ChunkyIconButtonStyle {
    static func chunkyIcon(_ tone: PlayfulTone) -> ChunkyIconButtonStyle { ChunkyIconButtonStyle(tone: tone) }
}
