import ComposableArchitecture
import DesignSystem
import Domain
import ShieldClient
import SwiftUI

struct OnboardingView: View {
    @Bindable var store: StoreOf<OnboardingFeature>
    @FocusState private var isTitleFocused: Bool

    /// 段階ごとの主役の色。
    private var tone: PlayfulTone {
        switch store.step {
        case .hook: Playful.coral
        case .mechanism: Playful.amber
        case .goal, .apps: Playful.sky
        case .ready: Playful.mint
        }
    }

    /// 段階ごとの、キャラクターの気分。
    private var mascotMood: LockMascot.Mood {
        switch store.step {
        case .hook: .locked
        case .mechanism: .nervous
        case .goal, .apps: .happy
        case .ready: .calm
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            progress
                .padding(.top, 12)

            // 段階が変わるたびに、キャラクターの表情と色が変わる。
            // 文字を入力している間は、キーボードに場所を譲って隠す。
            if !isTitleFocused {
                LockMascot(mood: mascotMood, tone: tone)
                    .padding(.top, 28)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }

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
            .transition(
                .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
                    .combined(with: .opacity)
            )
            .id(store.step)

            controls
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .foregroundStyle(Playful.text)
        .background(Playful.background.ignoresSafeArea())
        .environment(\.tone, tone)
        .animation(.smooth(duration: 0.45), value: store.step)
        .animation(.spring(duration: 0.35, bounce: 0.3), value: isTitleFocused)
        .sensoryFeedback(.impact(weight: .light), trigger: store.step)
    }

    // MARK: 段階ごとの内容

    private var hook: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Text(.onboardingHookTitle)
                .accessibilityIdentifier("onboarding.step.hook")
                .font(.hero(54))
                .minimumScaleFactor(0.7)
            Text(.onboardingHookBody)
                .font(.title3.weight(.medium))
                .foregroundStyle(Playful.text)
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
                .font(.hero(40))
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
                .foregroundStyle(tone.accent)
                .frame(width: 44, height: 44)
                .background(tone.face.opacity(0.16), in: .circle)
                .accessibilityHidden(true)
            Text(text)
                .font(.body.weight(.medium))
                .foregroundStyle(Playful.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
        }
    }

    private var goal: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer()
            Text(.onboardingGoalTitle)
                .accessibilityIdentifier("onboarding.step.goal")
                .font(.hero(36))
                .minimumScaleFactor(0.7)
            TextField(text: $store.goalTitle) {
                Text(.goalTitlePlaceholder)
            }
            .font(.title2.weight(.semibold))
            .focused($isTitleFocused)
            .accessibilityIdentifier("onboarding.goalTitle")
            .submitLabel(.done)
            .padding(18)
            .background(Playful.surface, in: .rect(cornerRadius: 20))
            .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(Playful.line, lineWidth: 2) }

            VStack(alignment: .leading, spacing: 10) {
                Text(.goalDailyHeader)
                    .chunkyHeading()
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
                                .foregroundStyle(isSelected ? .black.opacity(0.85) : Playful.text)
                                .background(
                                    isSelected ? AnyShapeStyle(tone.face) : AnyShapeStyle(Playful.line),
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
                .foregroundStyle(Playful.subtext)
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
                .font(.hero(36))
                .minimumScaleFactor(0.7)
            Text(.onboardingAppsBody)
                .font(.body.weight(.medium))
                .foregroundStyle(Playful.text)

            switch store.authorization {
            case .approved:
                Label {
                    Text(.onboardingAppsApproved(store.selectionCount))
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .font(.headline)
                .foregroundStyle(tone.accent)
                .accessibilityIdentifier("onboarding.apps.approved")
                Button {
                    store.send(.chooseAppsTapped)
                } label: {
                    Label { Text(.settingsShieldChoose) } icon: { Image(systemName: "lock.app.dashed") }
                }
                .buttonStyle(.chunkySecondary)
            case .denied:
                Text(.onboardingAppsDenied)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Playful.amber.accent)
            case .notDetermined:
                Button {
                    store.send(.allowTapped)
                } label: {
                    Label { Text(.onboardingAppsAllow) } icon: { Image(systemName: "hourglass") }
                }
                .buttonStyle(.chunkySecondary)
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
            Text(.onboardingReadyTitle)
                .accessibilityIdentifier("onboarding.step.ready")
                .font(.hero(38))
                .multilineTextAlignment(.center)
            Text(.onboardingReadyBody)
                .font(.body.weight(.medium))
                .foregroundStyle(Playful.text)
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
                    .fill(step.rawValue <= store.step.rawValue ? tone.face : Playful.line)
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
                .buttonStyle(.chunkyPrimary)
                .accessibilityIdentifier("onboarding.start")
            } else {
                Button {
                    isTitleFocused = false
                    store.send(.nextTapped)
                } label: {
                    Text(store.step == .apps && store.authorization != .approved ? .onboardingLater : .onboardingNext)
                }
                .buttonStyle(.chunkyPrimary)
                .disabled(!store.canAdvance)
                .accessibilityIdentifier("onboarding.next")
            }
            Button {
                store.send(.backTapped)
            } label: {
                Text(.onboardingBack)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Playful.subtext)
                    .frame(minHeight: 36)
            }
            .opacity(store.step == .hook ? 0 : 1)
            .disabled(store.step == .hook)
            .accessibilityIdentifier("onboarding.back")
        }
    }
}
