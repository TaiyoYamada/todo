import SwiftUI

public extension View {
    /// `trigger` が変わるたびに、`origin` から波紋を広げる。
    ///
    /// 「視差効果を減らす」が有効なときは何もしない。
    func ripple(at origin: CGPoint, trigger: some Equatable & Sendable) -> some View {
        modifier(RippleEffect(origin: origin, trigger: trigger))
    }
}

/// `trigger` が変わるたびに、キーフレームで時間を進めて波紋を描く。
///
/// Trigger に Sendable を求めているのは、下のクロージャがメインアクターに隔離されていて、
/// 型引数の情報(Trigger.Type)も一緒に取り込むため。Sendable でない型だと、並行処理の検査で警告になる。
private struct RippleEffect<Trigger: Equatable & Sendable>: ViewModifier {
    let origin: CGPoint
    let trigger: Trigger
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let duration: TimeInterval = 2.4

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, elapsed in
                view.modifier(RippleModifier(origin: origin, elapsed: elapsed, duration: duration))
            } keyframes: { _ in
                MoveKeyframe(0)
                LinearKeyframe(duration, duration: duration)
            }
        }
    }
}

/// ある時点の波紋を描く。時間の進行は呼び出し側(キーフレーム)が担う。
private struct RippleModifier: ViewModifier {
    let origin: CGPoint
    let elapsed: TimeInterval
    let duration: TimeInterval

    private let amplitude = 14.0
    private let frequency = 15.0
    private let decay = 6.0
    private let speed = 1100.0

    func body(content: Content) -> some View {
        let shader = ShaderLibrary.bundle(.module).Ripple(
            .float2(origin),
            .float(elapsed),
            .float(amplitude),
            .float(frequency),
            .float(decay),
            .float(speed)
        )
        let isActive = elapsed > 0 && elapsed < duration
        let offset = CGSize(width: amplitude, height: amplitude)
        content.visualEffect { view, _ in
            view.layerEffect(shader, maxSampleOffset: offset, isEnabled: isActive)
        }
    }
}
