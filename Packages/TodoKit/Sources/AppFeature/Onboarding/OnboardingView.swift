import ComposableArchitecture
import DesignSystem
import Domain
import ShieldClient
import SwiftUI

struct OnboardingView: View {
    @Bindable var store: StoreOf<OnboardingFeature>
    @FocusState private var isTitleFocused: Bool

    private var mood: Mood {
        switch store.step {
        case .hook: .locked
        case .mechanism: .warning
        case .goal, .apps: .calm
        case .ready: .free
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            progress
                .padding(.top, 12)

            Group {
                switch store.step {
                case .hook: hook
                case .mechanism: mechanism
                case .goal: goal
                case .apps: apps
                case .ready: ready
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
            .id(store.step)

            controls
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .foregroundStyle(.white)
        .background { AuroraBackground(mood: mood) }
        .environment(\.mood, mood)
        .animation(.smooth(duration: 0.45), value: store.step)
        .sensoryFeedback(.impact(weight: .light), trigger: store.step)
    }

    // MARK: 段階ごとの内容

    private var hook: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Text(.onboardingHookTitle)
                .accessibilityIdentifier("onboarding.step.hook")
                .font(.system(size: 54, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.7)
            Text(.onboardingHookBody)
                .font(.title3.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mechanism: some View {
        VStack(alignment: .leading, spacing: 26) {
            Spacer()
            Text(.onboardingMechanismTitle)
                .accessibilityIdentifier("onboarding.step.mechanism")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.7)
            VStack(alignment: .leading, spacing: 20) {
                point("lock.fill", .onboardingMechanismLock)
                point("timer", .onboardingMechanismSlack)
                point("lock.open.fill", .onboardingMechanismFree)
            }
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func point(_ symbol: String, _ text: LocalizedStringResource) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.title3.weight(.bold))
                .foregroundStyle(mood.accent)
                .frame(width: 44, height: 44)
                .background(mood.accent.opacity(0.16), in: .circle)
            Text(text)
                .font(.body.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
        }
    }

    private var goal: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer()
            Text(.onboardingGoalTitle)
                .accessibilityIdentifier("onboarding.step.goal")
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.7)
            TextField(text: $store.goalTitle) {
                Text(.goalTitlePlaceholder)
            }
            .font(.title2.weight(.semibold))
            .focused($isTitleFocused)
            .accessibilityIdentifier("onboarding.goalTitle")
            .submitLabel(.done)
            .padding(18)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))

            VStack(alignment: .leading, spacing: 10) {
                Text(.goalDailyHeader)
                    .sectionLabelStyle()
                HStack(spacing: 10) {
                    ForEach(OnboardingFeature.minutesPresets, id: \.self) { minutes in
                        let isSelected = minutes == store.goalMinutes
                        Button {
                            store.send(.minutesTapped(minutes))
                        } label: {
                            Text(DurationText.compact(minutes: minutes))
                                .font(.headline)
                                .monospacedDigit()
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .foregroundStyle(isSelected ? .black.opacity(0.85) : .white)
                                .background(
                                    isSelected ? AnyShapeStyle(mood.accent) : AnyShapeStyle(.white.opacity(0.14)),
                                    in: .capsule
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }
            Text(.onboardingGoalNote)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.65))
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sensoryFeedback(.selection, trigger: store.goalMinutes)
        .onAppear { isTitleFocused = store.goalTitle.isEmpty }
    }

    private var apps: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer()
            Text(.onboardingAppsTitle)
                .accessibilityIdentifier("onboarding.step.apps")
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.7)
            Text(.onboardingAppsBody)
                .font(.body.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))

            switch store.authorization {
            case .approved:
                Label {
                    Text(.onboardingAppsApproved(store.selectionCount))
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .font(.headline)
                .foregroundStyle(mood.accent)
                .accessibilityIdentifier("onboarding.apps.approved")
                Button {
                    store.send(.chooseAppsTapped)
                } label: {
                    Label { Text(.settingsShieldChoose) } icon: { Image(systemName: "lock.app.dashed") }
                }
                .buttonStyle(.quiet)
            case .denied:
                Text(.onboardingAppsDenied)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Mood.warning.accent)
            case .notDetermined:
                Button {
                    store.send(.allowTapped)
                } label: {
                    Label { Text(.onboardingAppsAllow) } icon: { Image(systemName: "hourglass") }
                }
                .buttonStyle(.quiet)
                .accessibilityIdentifier("onboarding.allow")
                .disabled(store.isRequestingAuthorization)
            }
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .shieldAppPicker(isPresented: $store.isPickerPresented) {
            store.send(.selectionChanged)
        } simulated: {
            ContentUnavailableView {
                Label { Text(.settingsShieldSimulatedTitle) } icon: { Image(systemName: "iphone.slash") }
            } description: {
                Text(.settingsShieldSimulatedBody)
            }
        }
    }

    private var ready: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 88, weight: .bold))
                .foregroundStyle(mood.accent)
                .symbolEffect(.bounce, value: store.step)
                .shadow(color: mood.accent.opacity(0.6), radius: 28)
            Text(.onboardingReadyTitle)
                .accessibilityIdentifier("onboarding.step.ready")
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
            Text(.onboardingReadyBody)
                .font(.body.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
    }

    // MARK: 進み具合と操作

    private var progress: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingFeature.Step.allCases, id: \.self) { step in
                Capsule()
                    .fill(.white.opacity(step.rawValue <= store.step.rawValue ? 0.9 : 0.22))
                    .frame(height: 4)
            }
        }
        .accessibilityHidden(true)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            if store.step == .ready {
                Button {
                    store.send(.finishTapped)
                } label: {
                    Text(.onboardingStart)
                }
                .buttonStyle(.hero)
                .accessibilityIdentifier("onboarding.start")
            } else {
                Button {
                    isTitleFocused = false
                    store.send(.nextTapped)
                } label: {
                    Text(store.step == .apps && store.authorization != .approved ? .onboardingLater : .onboardingNext)
                }
                .buttonStyle(.hero)
                .disabled(!store.canAdvance)
                .accessibilityIdentifier("onboarding.next")
            }
            Button {
                store.send(.backTapped)
            } label: {
                Text(.onboardingBack)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(minHeight: 36)
            }
            .opacity(store.step == .hook ? 0 : 1)
            .disabled(store.step == .hook)
            .accessibilityIdentifier("onboarding.back")
        }
    }
}
