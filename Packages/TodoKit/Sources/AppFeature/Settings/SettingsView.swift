import ComposableArchitecture
import DesignSystem
import Domain
import SwiftUI

struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(selection: $store.preferences.buffer) {
                        ForEach(Preferences.Buffer.allCases, id: \.self) { buffer in
                            Text(title(for: buffer)).tag(buffer)
                        }
                    } label: {
                        Text(.settingsBufferLabel)
                    }
                } header: {
                    Text(.settingsBufferHeader)
                } footer: {
                    Text(.settingsBufferFooter(factorText))
                }

                Section {
                    Stepper(value: $store.preferences.weeklyPassLimit, in: Preferences.weeklyPassLimitRange) {
                        LabeledContent {
                            Text(store.preferences.weeklyPassLimit, format: .number)
                                .monospacedDigit()
                        } label: {
                            Text(.settingsPassLabel)
                        }
                    }
                } header: {
                    Text(.settingsPassHeader)
                } footer: {
                    Text(.settingsPassFooter(DurationText.compact(minutes: store.preferences.passMinutes)))
                }

                Section {
                    Picker(selection: $store.preferences.dayStartHour) {
                        ForEach(Array(Preferences.dayStartHourRange), id: \.self) { hour in
                            Text(verbatim: "\(hour):00").tag(hour)
                        }
                    } label: {
                        Text(.settingsDayStartLabel)
                    }
                } header: {
                    Text(.settingsDayStartHeader)
                } footer: {
                    Text(.settingsDayStartFooter)
                }

                Section {
                    Button {
                        store.send(.replayOnboardingTapped)
                    } label: {
                        Text(.settingsReplayOnboarding)
                    }
                    LabeledContent {
                        Text(verbatim: Self.version)
                    } label: {
                        Text(.settingsVersion)
                    }
                }
            }
            .navigationTitle(Text(.todaySettings))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        store.send(.doneTapped)
                    } label: {
                        Text(.commonDone)
                    }
                }
            }
        }
    }

    private func title(for buffer: Preferences.Buffer) -> LocalizedStringResource {
        switch buffer {
        case .auto: .settingsBufferAuto
        case .none: .settingsBufferFixed("1")
        case .quarter: .settingsBufferFixed("1.25")
        case .half: .settingsBufferFixed("1.5")
        case .double: .settingsBufferFixed("2")
        }
    }

    private var factorText: String {
        store.board.world.estimateFactor.formatted(.number.precision(.fractionLength(0...2)))
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "-"
        let build = info?["CFBundleVersion"] as? String ?? "-"
        return "\(short) (\(build))"
    }
}
