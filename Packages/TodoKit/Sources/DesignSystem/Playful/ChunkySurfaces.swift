import SwiftUI

public extension View {
    /// 太い枠と、下に厚みのあるカードに載せる。
    func chunkyCard(cornerRadius: CGFloat = 20, padding: CGFloat = 16, border: Color = Playful.line) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Playful.surface, in: shape)
            .overlay { shape.strokeBorder(border, lineWidth: 2) }
            .background(alignment: .top) { shape.fill(border).offset(y: 4) }
            .padding(.bottom, 4)
    }

    /// 見出し用の文字。
    func chunkyHeading() -> some View {
        font(.system(.subheadline, design: .rounded, weight: .heavy))
            .foregroundStyle(Playful.subtext)
    }
}

/// 太い進み具合のバー。値が変わると、バネで伸び縮みする。
public struct ChunkyProgressBar: View {
    private let fraction: Double
    private let tone: PlayfulTone
    private let height: CGFloat

    public init(fraction: Double, tone: PlayfulTone, height: CGFloat = 14) {
        self.fraction = fraction
        self.tone = tone
        self.height = height
    }

    public var body: some View {
        GeometryReader { proxy in
            let clamped = max(0, min(1, fraction))
            // 少しでも進んでいれば、丸い端が見える幅は確保する。
            let width = clamped == 0 ? 0 : max(height, proxy.size.width * clamped)
            ZStack(alignment: .leading) {
                Capsule().fill(Playful.line)
                Capsule()
                    .fill(tone.face)
                    .frame(width: width)
                    // 上側に細い明るい帯を入れて、丸い棒に見せる。
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(.white.opacity(0.28))
                            .frame(height: height * 0.28)
                            .padding(.horizontal, height * 0.4)
                            .padding(.top, height * 0.2)
                    }
                    .clipShape(.capsule)
            }
        }
        .frame(height: height)
        .animation(.spring(duration: 0.6, bounce: 0.35), value: fraction)
        .accessibilityElement(children: .ignore)
        .accessibilityValue(Text(fraction, format: .percent.precision(.fractionLength(0))))
    }
}

/// キャラクターのせりふを入れる吹き出し。上に向かって、しっぽが出る。
public struct SpeechBubble<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .font(.system(.callout, design: .rounded, weight: .bold))
            .foregroundStyle(Playful.text)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .padding(.top, BubbleShape.tailHeight)
            .frame(maxWidth: .infinity)
            .background(Playful.surface, in: BubbleShape())
            .overlay { BubbleShape().stroke(Playful.line, lineWidth: 2) }
    }
}

/// 角の丸い四角の上辺に、三角のしっぽが付いた形。
private struct BubbleShape: Shape {
    static let tailHeight: CGFloat = 10
    private let tailWidth: CGFloat = 22
    private let cornerRadius: CGFloat = 18

    func path(in rect: CGRect) -> Path {
        let body = CGRect(
            x: rect.minX, y: rect.minY + Self.tailHeight, width: rect.width, height: rect.height - Self.tailHeight
        )
        var tail = Path()
        tail.move(to: CGPoint(x: rect.midX - tailWidth / 2, y: body.minY + 1))
        tail.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        tail.addLine(to: CGPoint(x: rect.midX + tailWidth / 2, y: body.minY + 1))
        tail.closeSubpath()
        return Path(roundedRect: body, cornerRadius: cornerRadius, style: .continuous).union(tail)
    }
}
