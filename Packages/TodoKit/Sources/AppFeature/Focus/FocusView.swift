import ComposableArchitecture
import DesignSystem
import Domain
import SwiftUI

struct FocusView: View {
    let store: StoreOf<FocusFeature>

    var body: some View {
        let tone = store.goal.tint.tone
        ZStack {
            Playful.background.ignoresSafeArea()
            switch store.phase {
            case .running:
                RunningView(store: store)
                    .transition(.opacity)
            case let .finished(summary):
                FinishedView(store: store, summary: summary)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .environment(\.tone, tone)
        .foregroundStyle(Playful.text)
        // 今日の分に達した瞬間、画面の中央上から波紋を広げる。
        .ripple(at: CGPoint(x: 200, y: 320), trigger: reachedTarget)
        .animation(.spring(duration: 0.6), value: store.phase)
        .task { await store.send(.task).finish() }
        // 計測中は画面を消さない。机に置いたまま残り時間を見られるように。
        .persistentSystemOverlays(.hidden)
        .interactiveDismissDisabled()
    }
}

private extension FocusView {
    /// 今日の分に達して終わったか。
    var reachedTarget: Bool {
        if case let .finished(summary) = store.phase { summary.reachedTarget } else { false }
    }
}

private struct RunningView: View {
    let store: StoreOf<FocusFeature>
    @Environment(\.tone) private var tone

    var body: some View {
        VStack(spacing: 0) {
            Label {
                Text(store.goal.title)
            } icon: {
                Image(systemName: store.goal.symbol)
            }
            .font(.title3.weight(.semibold))
            .padding(.top, 36)

            Spacer()

            TimelineView(.periodic(from: store.startedAt, by: 1)) { timeline in
                let elapsed = max(0, timeline.date.timeIntervalSince(store.startedAt))
                let done = Double(store.baseSeconds) + elapsed
                ProgressRing(
                    fraction: store.goal.dailySeconds == 0 ? 1 : done / Double(store.goal.dailySeconds),
                    lineWidth: 18,
                    tint: tone.face
                ) {
                    VStack(spacing: 6) {
                        clock
                        Text(caption)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Playful.subtext)
                    }
                }
                .frame(width: 290, height: 290)
            }

            Spacer()

            Button {
                store.send(.stopTapped)
            } label: {
                Label { Text(.focusStop) } icon: { Image(systemName: "stop.fill") }
            }
            .buttonStyle(.chunkySecondary)
            .accessibilityIdentifier("focus.stop")
            .padding(.bottom, 44)
        }
        .padding(.horizontal, 24)
    }

    /// 今日の分までは残り時間を、達したあとは経過時間を出す。
    private var clock: some View {
        Group {
            if let endsAt = store.endsAt {
                Text(timerInterval: store.startedAt ... endsAt, countsDown: true)
            } else {
                Text(store.startedAt, style: .timer)
            }
        }
        .font(.hero(64))
        .monospacedDigit()
        .minimumScaleFactor(0.6)
        .lineLimit(1)
        .padding(.horizontal, 28)
    }

    private var caption: LocalizedStringResource {
        store.endsAt == nil ? .focusCaptionExtra : .focusCaptionRemaining
    }
}

private struct FinishedView: View {
    let store: StoreOf<FocusFeature>
    let summary: FocusFeature.State.Summary
    @Environment(\.tone) private var tone
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            // 今日の分を終えたら、掛け金を開いて喜ぶ。途中で止めたときは、見守っている。
            LockMascot(mood: summary.reachedTarget ? .happy : .watching, tone: tone)

            Text(summary.reachedTarget ? .focusFinishedTitleDone : .focusFinishedTitlePaused)
                .accessibilityIdentifier("focus.finished.title")
                .font(.hero(36))
                .multilineTextAlignment(.center)

            Text(.focusFinishedSession(DurationText.compact(seconds: summary.sessionSeconds)))
                .font(.title3.weight(.medium))
                .foregroundStyle(Playful.text)

            lockLine
                .padding(.top, 4)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    store.send(.closeTapped)
                } label: {
                    Text(.commonClose)
                }
                .buttonStyle(.chunkyPrimary)
                .accessibilityIdentifier("focus.close")

                Button {
                    store.send(.continueTapped)
                } label: {
                    Text(summary.reachedTarget ? .focusContinueExtra : .focusContinue)
                }
                .buttonStyle(.chunkySecondary)
                .accessibilityIdentifier("focus.continue")
            }
            .padding(.bottom, 36)
        }
        .padding(.horizontal, 24)
        .background {
            if summary.reachedTarget {
                CelebrationBurst(
                    colors: [tone.face, Playful.amber.face, Playful.sky.face, Playful.coral.face],
                    trigger: appeared ? 1 : 0
                )
                .ignoresSafeArea()
            }
        }
        .onAppear {
            appeared = true
            if summary.reachedTarget {
                Haptics.playCelebration()
            }
        }
        .sensoryFeedback(.impact, trigger: appeared) { _, _ in !summary.reachedTarget }
    }

    /// この計測でロックがどうなったかを一言で伝える。終えた直後に一番知りたいこと。
    @ViewBuilder
    private var lockLine: some View {
        let status = store.board.status
        switch status.phase {
        case .locked, .onPass:
            Label {
                Text(.focusLockRemaining(status.activeReasons.count))
            } icon: {
                Image(systemName: "lock.fill")
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(Playful.subtext)
        case .free:
            if summary.reachedTarget {
                Label {
                    Text(status.isFreeForToday ? .focusLockFreeToday : .focusLockOpen)
                } icon: {
                    Image(systemName: "lock.open.fill")
                }
                .font(.callout.weight(.semibold))
                .foregroundStyle(tone.accent)
            }
        }
    }
}
