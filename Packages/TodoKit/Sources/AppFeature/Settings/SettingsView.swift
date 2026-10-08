import ComposableArchitecture
import DesignSystem
import Domain
import ShieldClient
import SwiftUI

struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>

    var body: some View {
        NavigationStack {
            Form {
                shieldSection

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
                    .accessibilityIdentifier("settings.replayOnboarding")
                    LabeledContent {
                        Text(verbatim: Self.version)
                    } label: {
                        Text(.settingsVersion)
                    }
                }
            }
            .navigationTitle(Text(.todaySettings))
            .navigationBarTitleDisplayMode(.inline)
            .task { await store.send(.task).finish() }
            .shieldAppPicker(isPresented: $store.isPickerPresented) {
                store.send(.selectionChanged)
            } simulated: {
                ContentUnavailableView {
                    Label { Text(.settingsShieldSimulatedTitle) } icon: { Image(systemName: "iphone.slash") }
                } description: {
                    Text(.settingsShieldSimulatedBody)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        store.send(.doneTapped)
                    } label: {
                        Text(.commonDone)
                    }
                    .accessibilityIdentifier("settings.done")
                }
            }
        }
    }

    private var shieldSection: some View {
        Section {
            switch store.authorization {
            case .approved:
                Button {
                    store.send(.chooseAppsTapped)
                } label: {
                    LabeledContent {
                        Text(.settingsShieldCount(store.selectionCount))
                    } label: {
                        Label { Text(.settingsShieldChoose) } icon: { Image(systemName: "lock.app.dashed") }
                    }
                }
            case .notDetermined:
                Button {
                    store.send(.allowTapped)
                } label: {
                    Label { Text(.onboardingAppsAllow) } icon: { Image(systemName: "hourglass") }
                }
            case .denied:
                Label { Text(.onboardingAppsDenied) } icon: { Image(systemName: "exclamationmark.triangle") }
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(.settingsShieldHeader)
        } footer: {
            Text(.settingsShieldFooter)
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
