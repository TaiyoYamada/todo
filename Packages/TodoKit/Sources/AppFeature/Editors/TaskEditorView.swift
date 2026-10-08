import ComposableArchitecture
import DesignSystem
import Domain
import SwiftUI

struct TaskEditorView: View {
    @Bindable var store: StoreOf<TaskEditorFeature>
    @FocusState private var isTitleFocused: Bool
    @Environment(\.mood) private var mood

    private let tint = Mood.calm.accent

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(text: $store.task.title) {
                        Text(.taskTitlePlaceholder)
                    }
                    .font(.title3.weight(.semibold))
                    .focused($isTitleFocused)
                    .accessibilityIdentifier("taskEditor.title")
                    if let suggestion = store.suggestion {
                        Button {
                            store.send(.applySuggestionTapped)
                        } label: {
                            Label {
                                Text(.taskSuggestionApply(suggestionText(suggestion)))
                                    .multilineTextAlignment(.leading)
                            } icon: {
                                Image(systemName: "sparkles")
                            }
                            .font(.subheadline.weight(.semibold))
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .accessibilityIdentifier("taskEditor.suggestion")
                    }
                } footer: {
                    if store.isNew {
                        Text(.taskTitleFooter)
                    }
                }
                .animation(.snappy, value: store.suggestion)

                Section {
                    DatePicker(selection: $store.task.dueAt) {
                        Text(.taskDueLabel)
                    }
                } header: {
                    Text(.taskDueHeader)
                }

                Section {
                    MinutesPicker(
                        minutes: $store.task.estimateMinutes,
                        range: TaskEditorFeature.estimateRange,
                        step: TaskEditorFeature.estimateStep,
                        presets: TaskEditorFeature.estimatePresets,
                        tint: tint
                    )
                } header: {
                    Text(.taskEstimateHeader)
                }

                if store.task.isOpen {
                    Section {
                        LabeledContent {
                            Text(TimeText.dayAndClock(store.startLimit))
                                .font(.body.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(store.locksImmediately ? .red : .primary)
                        } label: {
                            Label {
                                Text(.taskStartLimitLabel)
                            } icon: {
                                Image(systemName: store.locksImmediately ? "lock.fill" : "lock.open")
                            }
                        }
                    } footer: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(.taskStartLimitFooter(factorText))
                            if store.locksImmediately {
                                Text(.taskLocksImmediately)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }

                if !store.isNew {
                    statusSection
                }
            }
            .navigationTitle(Text(store.isNew ? .taskNewTitle : .taskEditTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        store.send(.cancelTapped)
                    } label: {
                        Text(.commonCancel)
                    }
                    .accessibilityIdentifier("taskEditor.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        store.send(.saveTapped)
                    } label: {
                        Text(store.isNew ? .commonAdd : .commonSave)
                    }
                    .disabled(!store.canSave)
                    .accessibilityIdentifier("taskEditor.save")
                }
            }
            .tint(tint)
            .onAppear { isTitleFocused = store.isNew }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if store.task.isOpen {
            Section {
                Button {
                    store.send(.completeTapped)
                } label: {
                    Label { Text(.todayCtaCompleteTask) } icon: { Image(systemName: "checkmark.circle.fill") }
                }
            }
            Section {
                HoldToConfirmButton(tint: .orange) {
                    store.send(.withdrawConfirmed)
                } label: {
                    Text(.taskWithdrawHold)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } footer: {
                Text(.taskWithdrawFooter)
            }
        } else {
            Section {
                Button {
                    store.send(.reopenTapped)
                } label: {
                    Label { Text(.taskReopen) } icon: { Image(systemName: "arrow.uturn.backward") }
                }
            }
        }
        Section {
            HoldToConfirmButton(tint: .red) {
                store.send(.deleteConfirmed)
            } label: {
                Text(.taskDeleteHold)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    /// 読み取れた内容を「明日 18:00 · 1時間30分」の形にする。
    private func suggestionText(_ suggestion: QuickAdd) -> String {
        [
            suggestion.dueAt.map { TimeText.dayAndClock($0) },
            suggestion.estimateMinutes.map { DurationText.compact(minutes: $0) },
        ]
        .compactMap(\.self)
        .joined(separator: " · ")
    }

    private var factorText: String {
        store.board.world.estimateFactor.formatted(.number.precision(.fractionLength(0...2)))
    }
}
