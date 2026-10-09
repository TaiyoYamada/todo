import ComposableArchitecture
import DesignSystem
import Domain
import SwiftUI

struct TaskCompletionView: View {
    let store: StoreOf<TaskCompletionFeature>
    private let tone = Playful.mint

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(.completionTitle)
                    .accessibilityIdentifier("completion.title")
                    .font(.title2.weight(.bold))
                Text(store.task.title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(.completionQuestion)
                    .font(.subheadline.weight(.semibold))
                ChipRow(values: store.options, selection: store.actualMinutes, tint: tone.face) {
                    store.send(.optionTapped($0))
                }
                Group {
                    if let measured = store.measuredMinutes {
                        Text(
                            .completionMeasured(
                                DurationText.compact(minutes: measured),
                                DurationText.compact(minutes: store.task.estimateMinutes)
                            )
                        )
                    } else {
                        Text(.completionEstimate(DurationText.compact(minutes: store.task.estimateMinutes)))
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button {
                store.send(.confirmTapped)
            } label: {
                Label { Text(.completionConfirm) } icon: { Image(systemName: "checkmark") }
            }
            .buttonStyle(.chunkyPrimary)
            .accessibilityIdentifier("completion.confirm")

            Button {
                store.send(.cancelTapped)
            } label: {
                Text(.completionNotYet)
                    .frame(maxWidth: .infinity)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("completion.cancel")
        }
        .padding(24)
        .environment(\.tone, tone)
        .sensoryFeedback(.selection, trigger: store.actualMinutes)
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.visible)
    }
}
