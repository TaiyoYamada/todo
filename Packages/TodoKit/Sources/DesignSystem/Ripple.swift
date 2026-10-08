import SwiftUI

extension View {
    /// `trigger` が変わるたびに、`origin` から波紋を広げる。
    ///
    /// 「視差効果を減らす」が有効なときは何もしない。
    public func ripple(at origin: CGPoint, trigger: some Equatable) -> some View {
        modifier(RippleEffect(origin: origin, trigger: trigger))
    }
}

private struct RippleEffect<Trigger: Equatable>: ViewModifier {
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
