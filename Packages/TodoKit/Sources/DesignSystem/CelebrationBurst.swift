import SwiftUI

/// 中心から紙吹雪がはじける演出。今日の分を終えた瞬間に重ねる。
///
/// `trigger` が変わるたびに1回だけ再生する。粒の位置は毎フレーム計算で求めるので、
/// 状態を持たず、何度再生しても同じ動きになる。
public struct CelebrationBurst: View {
    private let colors: [Color]
    private let trigger: Int

    @State private var startedAt: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let duration: TimeInterval = 1.8
    private static let particleCount = 64

    public init(colors: [Color], trigger: Int) {
        self.colors = colors
        self.trigger = trigger
    }

    public var body: some View {
        TimelineView(.animation(paused: startedAt == nil)) { timeline in
            Canvas { context, size in
                guard let startedAt else { return }
                let elapsed = timeline.date.timeIntervalSince(startedAt)
                guard elapsed < Self.duration else { return }
                draw(in: &context, size: size, progress: elapsed / Self.duration)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger, initial: true) {
            guard trigger > 0, !reduceMotion else { return }
            startedAt = .now
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, progress: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.36)
        let reach = max(size.width, size.height) * 0.62
        // 勢いよく飛び出して、ゆっくり止まる。
        let eased = 1 - pow(1 - progress, 3)

        for index in 0 ..< Self.particleCount {
            // 粒ごとの違いは、番号から決まる疑似乱数で作る。毎フレーム同じ値になる必要があるため。
            let seed = Double(index)
            let angle = Self.noise(seed * 12.9898) * 2 * .pi
            let distance = reach * (0.35 + 0.65 * Self.noise(seed * 78.233)) * eased
            let radius = 2.5 + 4.5 * Self.noise(seed * 37.719)
            let gravity = 90 * progress * progress

            let point = CGPoint(
                x: center.x + cos(angle) * distance,
                y: center.y + sin(angle) * distance + gravity
            )
            let opacity = (1 - progress) * (0.5 + 0.5 * Self.noise(seed * 4.123))
            let color = colors.isEmpty ? Color.white : colors[index % colors.count]

            // 紙吹雪の1枚。単色の小さな四角を、飛びながら回す。
            var particle = context
            particle.opacity = min(1, opacity * 1.6)
            particle.translateBy(x: point.x, y: point.y)
            particle.rotate(by: .radians(progress * 9 * (Self.noise(seed * 9.17) - 0.5) + angle))
            particle.fill(
                Path(
                    roundedRect: CGRect(x: -radius, y: -radius * 0.6, width: radius * 2, height: radius * 1.2),
                    cornerRadius: 1.5
                ),
                with: .color(color)
            )
        }
    }

    /// 0 以上 1 未満の、入力から決まる値。
    private static func noise(_ value: Double) -> Double {
        let scaled = sin(value) * 43758.5453
        return scaled - floor(scaled)
    }
}

#Preview {
    @Previewable @State var trigger = 1
    ZStack {
        Color.black.ignoresSafeArea()
        CelebrationBurst(colors: [.mint, .white, .cyan], trigger: trigger)
        Button("もう一度") { trigger += 1 }
    }
}
