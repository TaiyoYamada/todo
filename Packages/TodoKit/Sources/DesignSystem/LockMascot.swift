import SwiftUI

/// 錠前のキャラクター。ロックの状態を、表情と動きで伝える。
///
/// 絵の素材は使わず、丸と線だけで描いている。動きは時刻から計算するので、状態を持たない。
/// 「視差効果を減らす」が有効なときは、止まった絵になる。
public struct LockMascot: View {
    public enum Mood: Equatable, Sendable {
        /// 今日はもうロックしない。うとうとしている。
        case sleepy
        /// 余裕がある。掛け金は開いている。
        case calm
        /// ロックが近い。そわそわしている。
        case nervous
        /// ロック中。掛け金を閉じて、きりっとしている。
        case locked
        /// 見守っている(作業中、パス中)。
        case watching
        /// まだ何もない。にこにこ待っている。
        case happy
    }

    private let mood: Mood
    private let tone: PlayfulTone

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let ink = Color(hex: 0x10161D)
    private static let bodySize = CGSize(width: 116, height: 88)
    private static let depth: CGFloat = 6

    public init(mood: Mood, tone: PlayfulTone) {
        self.mood = mood
        self.tone = tone
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            figure(time: reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate)
        }
        .frame(width: 136, height: 150, alignment: .bottom)
        // 気分が変わった瞬間に、ぽんと弾む。
        .phaseAnimator([1.0, 1.16, 1.0], trigger: mood) { view, scale in
            view.scaleEffect(scale, anchor: .bottom)
        } animation: { _ in
            .spring(duration: 0.28, bounce: 0.6)
        }
        .animation(.spring(duration: 0.5, bounce: 0.5), value: mood)
        .accessibilityHidden(true)
    }

    private func figure(time: TimeInterval) -> some View {
        // 呼吸するように、ゆっくり伸び縮みする。
        let breath = sin(time * 2.2) * 0.022
        // そわそわしているときは、小刻みに震える。
        let shake = mood == .nervous ? sin(time * 34) * 1.6 : 0
        let isOpen = mood != .locked

        return ZStack(alignment: .bottom) {
            ShackleShape()
                .stroke(tone.edge, style: StrokeStyle(lineWidth: 15, lineCap: .round))
                .frame(width: 62, height: 66)
                // 開いているときは、右の足を軸に持ち上がる。
                .rotationEffect(.degrees(isOpen ? -22 : 0), anchor: .bottomTrailing)
                .offset(y: -(Self.depth + Self.bodySize.height - 18) - (isOpen ? 12 : 0))

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(tone.edge)
                .frame(width: Self.bodySize.width, height: Self.bodySize.height)

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(tone.face)
                .frame(width: Self.bodySize.width, height: Self.bodySize.height)
                .overlay { face(time: time) }
                .offset(y: -Self.depth)

            extras(time: time)
        }
        .scaleEffect(x: 1 - breath, y: 1 + breath, anchor: .bottom)
        .offset(x: shake)
    }

    // MARK: 顔

    private func face(time: TimeInterval) -> some View {
        VStack(spacing: 9) {
            HStack(spacing: 20) {
                eye(time: time, isLeft: true)
                eye(time: time, isLeft: false)
            }
            mouth
        }
        .offset(y: -2)
    }

    @ViewBuilder
    private func eye(time: TimeInterval, isLeft: Bool) -> some View {
        if mood == .happy {
            // にこにこ。目は山なりの線。
            ArcShape()
                .stroke(Self.ink, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                .frame(width: 20, height: 11)
                .frame(height: 26)
        } else {
            let blinking = time.truncatingRemainder(dividingBy: 3.4) < 0.14
            ZStack {
                Ellipse().fill(.white)
                Circle()
                    .fill(Self.ink)
                    .frame(width: mood == .nervous ? 8 : 11)
                    .offset(pupilOffset(time: time))
            }
            .frame(width: 22, height: 26)
            .scaleEffect(y: blinking ? 0.1 : lidScale)
            .overlay(alignment: .top) {
                if mood == .locked {
                    // きりっとした眉。
                    Capsule()
                        .fill(Self.ink)
                        .frame(width: 20, height: 5)
                        .rotationEffect(.degrees(isLeft ? 16 : -16))
                        .offset(y: -7)
                }
            }
        }
    }

    /// まぶたの開き具合。
    private var lidScale: CGFloat {
        switch mood {
        case .sleepy: 0.34
        case .nervous: 1.12
        default: 1
        }
    }

    private func pupilOffset(time: TimeInterval) -> CGSize {
        switch mood {
        case .nervous: CGSize(width: sin(time * 9) * 3.2, height: 0)
        case .sleepy: CGSize(width: 0, height: 3)
        case .locked: .zero
        default: CGSize(width: sin(time * 0.7) * 2.2, height: cos(time * 0.5) * 1.2)
        }
    }

    @ViewBuilder
    private var mouth: some View {
        switch mood {
        case .happy:
            HalfDiscShape().fill(Self.ink).frame(width: 22, height: 11)
        case .calm, .watching:
            ArcShape()
                .stroke(Self.ink, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 20, height: 8)
                .rotationEffect(.degrees(180))
        case .locked:
            Capsule().fill(Self.ink).frame(width: 18, height: 4.5)
        case .nervous:
            Ellipse().fill(Self.ink).frame(width: 9, height: 11)
        case .sleepy:
            Capsule().fill(Self.ink).frame(width: 10, height: 4)
        }
    }

    // MARK: 気分ごとの小物

    @ViewBuilder
    private func extras(time: TimeInterval) -> some View {
        switch mood {
        case .nervous:
            // 汗が、くり返し流れ落ちる。
            let progress = time.truncatingRemainder(dividingBy: 1.1) / 1.1
            Circle()
                .fill(Playful.sky.face)
                .frame(width: 9, height: 9)
                .offset(x: 46, y: -74 + progress * 20)
                .opacity(1 - progress)
        case .sleepy:
            // 「z」が、ゆっくり昇って消える。
            let progress = time.truncatingRemainder(dividingBy: 2.4) / 2.4
            Text(verbatim: "z")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(Playful.subtext)
                .offset(x: 52 + progress * 8, y: -92 - progress * 24)
                .opacity(1 - progress)
        default:
            EmptyView()
        }
    }
}

/// 掛け金。上が半円の、逆さの U 字。
private struct ShackleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = rect.width / 2
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

/// 山なりの弧。
private struct ArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.minY - rect.height)
        )
        return path
    }
}

/// 下半分の円。開いた口。
private struct HalfDiscShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.maxY * 2)
        )
        return path
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 24) {
            LockMascot(mood: .happy, tone: Playful.sky)
            LockMascot(mood: .calm, tone: Playful.mint)
            LockMascot(mood: .nervous, tone: Playful.amber)
            LockMascot(mood: .locked, tone: Playful.coral)
            LockMascot(mood: .watching, tone: Playful.amber)
            LockMascot(mood: .sleepy, tone: Playful.mint)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    .background(Playful.background)
}
