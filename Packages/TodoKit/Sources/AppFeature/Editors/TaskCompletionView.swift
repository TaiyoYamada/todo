import ComposableArchitecture
import DesignSystem
import Domain
import SwiftUI

struct TaskCompletionView: View {
    let store: StoreOf<TaskCompletionFeature>
    private let mood = Mood.free

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(.completionTitle)
                    .font(.title2.weight(.bold))
                Text(store.task.title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(.completionQuestion)
                    .font(.subheadline.weight(.semibold))
                ChipRow(values: store.options, selection: store.actualMinutes, tint: mood.accent) {
                    store.send(.optionTapped($0))
                }
                Text(.completionEstimate(DurationText.compact(minutes: store.task.estimateMinutes)))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button {
                store.send(.confirmTapped)
            } label: {
                Label { Text(.completionConfirm) } icon: { Image(systemName: "checkmark") }
            }
            .buttonStyle(.hero)

            Button {
                store.send(.cancelTapped)
            } label: {
                Text(.completionNotYet)
                    .frame(maxWidth: .infinity)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .padding(24)
        .environment(\.mood, mood)
        .sensoryFeedback(.selection, trigger: store.actualMinutes)
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.visible)
    }
}
