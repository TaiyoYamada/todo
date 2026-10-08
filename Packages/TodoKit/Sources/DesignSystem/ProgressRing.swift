import SwiftUI

/// 進み具合を表す輪。
public struct ProgressRing<Center: View>: View {
    private let fraction: Double
    private let lineWidth: CGFloat
    private let tint: Color
    private let center: Center

    public init(
        fraction: Double,
        lineWidth: CGFloat = 6,
        tint: Color,
        @ViewBuilder center: () -> Center = { EmptyView() }
    ) {
        self.fraction = fraction
        self.lineWidth = lineWidth
        self.tint = tint
        self.center = center()
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.14), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, fraction)))
                .stroke(
                    AngularGradient(
                        colors: [tint.opacity(0.55), tint],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * max(0.05, fraction))
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.6), radius: lineWidth, y: 0)
            center
        }
        .animation(.spring(duration: 0.6), value: fraction)
        .accessibilityElement(children: .ignore)
        .accessibilityValue(Text(fraction, format: .percent.precision(.fractionLength(0))))
    }
}

#Preview {
    ProgressRing(fraction: 0.62, lineWidth: 14, tint: .mint) {
        Text("62%").font(.title.bold())
    }
    .frame(width: 160, height: 160)
    .padding()
    .background(.black)
}
