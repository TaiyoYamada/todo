import SwiftUI

/// ゆっくり流れるグラデーションの背景。
///
/// 色の組(`Mood`)が変わると、なめらかに次の色へ移る。
/// 「視差効果を減らす」が有効なときは動きを止める。
public struct AuroraBackground: View {
    private let mood: Mood
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(mood: Mood) {
        self.mood = mood
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            MeshGradient(
                width: 3,
                height: 3,
                points: Self.points(at: time),
                colors: colors,
                smoothsColors: true
            )
        }
        .animation(.smooth(duration: 1.2), value: mood)
        .ignoresSafeArea()
    }

    /// 3×3 の格子に色を割り当てる。四隅を暗く、中央付近を明るくして奥行きを出す。
    private var colors: [Color] {
        let palette = mood.backdrop
        guard palette.count >= 4 else { return Array(repeating: .black, count: 9) }
        return [
            palette[0], palette[1], palette[0],
            palette[3], palette[2], palette[1],
            palette[0], palette[3], palette[0],
        ]
    }

    /// 格子の内側の点だけを、周期の違う波で揺らす。外周は動かさない(端に隙間が出ないように)。
    private static func points(at time: TimeInterval) -> [SIMD2<Float>] {
        func wave(_ speed: Double, _ phase: Double) -> Float {
            Float(sin(time * speed + phase))
        }
        return [
            [0, 0], [0.5 + 0.12 * wave(0.21, 0), 0], [1, 0],
            [0, 0.5 + 0.10 * wave(0.17, 1.3)],
            [0.5 + 0.18 * wave(0.13, 2.1), 0.5 + 0.16 * wave(0.19, 0.7)],
            [1, 0.5 + 0.10 * wave(0.23, 3.4)],
            [0, 1], [0.5 + 0.12 * wave(0.15, 4.2), 1], [1, 1],
        ]
    }
}

#Preview("calm") { AuroraBackground(mood: .calm) }
#Preview("locked") { AuroraBackground(mood: .locked) }
