import DesignSystem
import SwiftUI

/// 分数を選ぶ行。大きな数字、増減のボタン、よく使う値の選択肢を並べる。
struct MinutesPicker: View {
    @Binding var minutes: Int
    let range: ClosedRange<Int>
    let step: Int
    let presets: [Int]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Stepper(value: $minutes, in: range, step: step) {
                Text(DurationText.compact(minutes: minutes))
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(minutes)))
                    .animation(.snappy, value: minutes)
            }
            ChipRow(values: presets, selection: minutes, tint: tint) { minutes = $0 }
        }
        .sensoryFeedback(.selection, trigger: minutes)
    }
}

/// 時間の選択肢を横に並べたもの。
struct ChipRow: View {
    let values: [Int]
    let selection: Int
    let tint: Color
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(values, id: \.self) { value in
                    let isSelected = value == selection
                    Button {
                        onSelect(value)
                    } label: {
                        Text(DurationText.compact(minutes: value))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .padding(.vertical, 9)
                            .padding(.horizontal, 14)
                            .foregroundStyle(isSelected ? .black.opacity(0.85) : .primary)
                            .background(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(.quaternary), in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityIdentifier("chip.\(value)")
                }
            }
        }
        .scrollIndicators(.hidden)
        .animation(.snappy, value: selection)
    }
}
