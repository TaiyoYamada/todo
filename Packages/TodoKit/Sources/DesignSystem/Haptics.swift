import CoreHaptics
import Foundation

/// 手応えの演出。達成の瞬間を、振動でも伝える。
@MainActor
public enum Haptics {
    private static var engine: CHHapticEngine?

    /// 今日の分を終えたときの振動。小さな刻みが3つ続いたあとに、大きな1つが来る。
    public static func playCelebration() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try engine ?? CHHapticEngine()
            Self.engine = engine
            try engine.start()

            var events: [CHHapticEvent] = []
            for step in 0 ..< 3 {
                events.append(
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.35 + 0.15 * Float(step)),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6),
                        ],
                        relativeTime: 0.09 * Double(step)
                    )
                )
            }
            events.append(
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3),
                    ],
                    relativeTime: 0.34,
                    duration: 0.28
                )
            )
            let player = try engine.makePlayer(with: CHHapticPattern(events: events, parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // 振動は飾りなので、鳴らせなくても何もしない。
        }
    }
}
