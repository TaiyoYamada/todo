import SwiftUI

/// 押し続けて初めて実行されるボタン。
///
/// パスの使用やタスクの取り下げのように、うっかり押してほしくない操作に使う。
/// 押している間は輪が進み、指を離すと戻る。
public struct HoldToConfirmButton<Label: View>: View {
    private let duration: Duration
    private let tint: Color
    private let action: () -> Void
    private let label: Label

    @State private var isPressing = false
    @State private var completed = 0

    public init(
        duration: Duration = .seconds(3),
        tint: Color,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.duration = duration
        self.tint = tint
        self.action = action
        self.label = label()
    }

    public var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(Playful.line, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: isPressing ? 1 : 0)
                    .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(
                        isPressing ? .linear(duration: seconds) : .easeOut(duration: 0.25),
                        value: isPressing
                    )
            }
            .frame(width: 22, height: 22)
            label
        }
        .font(.system(.subheadline, design: .rounded, weight: .heavy))
        .foregroundStyle(Playful.text)
        .padding(.vertical, 13)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .background(Playful.surface, in: .rect(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(isPressing ? tint : Playful.line, lineWidth: 2) }
        .contentShape(.rect(cornerRadius: 16))
        .scaleEffect(isPressing ? 0.98 : 1)
        .animation(.easeOut(duration: 0.2), value: isPressing)
        .onLongPressGesture(minimumDuration: seconds, maximumDistance: 60) {
            completed += 1
            isPressing = false
            action()
        } onPressingChanged: { pressing in
            isPressing = pressing
        }
        .sensoryFeedback(.impact(weight: .light), trigger: isPressing) { _, new in new }
        .sensoryFeedback(.success, trigger: completed)
        .accessibilityAddTraits(.isButton)
        // VoiceOver では長押しができないので、通常の実行操作として公開する。確認は呼び出し側で挟む。
        .accessibilityAction { action() }
    }

    private var seconds: Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }
}
