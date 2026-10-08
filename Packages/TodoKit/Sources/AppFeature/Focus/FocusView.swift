import ComposableArchitecture
import DesignSystem
import Domain
import SwiftUI

struct FocusView: View {
    let store: StoreOf<FocusFeature>

    var body: some View {
        let mood = Mood.focus(store.goal.tint)
        ZStack {
            AuroraBackground(mood: mood)
            switch store.phase {
            case .running:
                RunningView(store: store)
                    .transition(.opacity)
            case let .finished(summary):
                FinishedView(store: store, summary: summary)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
        .environment(\.mood, mood)
        .foregroundStyle(.white)
        .animation(.spring(duration: 0.6), value: store.phase)
        .task { await store.send(.task).finish() }
        // 計測中は画面を消さない。机に置いたまま残り時間を見られるように。
        .persistentSystemOverlays(.hidden)
        .interactiveDismissDisabled()
    }
}

private struct RunningView: View {
    let store: StoreOf<FocusFeature>
    @Environment(\.mood) private var mood

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
                    tint: mood.accent
                ) {
                    VStack(spacing: 6) {
                        clock
                        Text(caption)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))
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
            .buttonStyle(.quiet)
            .padding(.bottom, 44)
        }
        .padding(.horizontal, 24)
    }

    /// 今日の分までは残り時間を、達したあとは経過時間を出す。
    @ViewBuilder
    private var clock: some View {
        Group {
            if let endsAt = store.endsAt {
                Text(timerInterval: store.startedAt...endsAt, countsDown: true)
            } else {
                Text(store.startedAt, style: .timer)
            }
        }
        .font(.system(size: 64, weight: .heavy, design: .rounded))
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
    @Environment(\.mood) private var mood
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: summary.reachedTarget ? "checkmark.seal.fill" : "pause.circle.fill")
                .font(.system(size: 96, weight: .bold))
                .foregroundStyle(mood.accent)
                .symbolEffect(.bounce, value: appeared)
                .shadow(color: mood.accent.opacity(0.7), radius: 30)

            Text(summary.reachedTarget ? .focusFinishedTitleDone : .focusFinishedTitlePaused)
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)

            Text(.focusFinishedSession(DurationText.compact(seconds: summary.sessionSeconds)))
                .font(.title3.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))

            lockLine
                .padding(.top, 4)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    store.send(.closeTapped)
                } label: {
                    Text(.commonClose)
                }
                .buttonStyle(.hero)

                Button {
                    store.send(.continueTapped)
                } label: {
                    Text(summary.reachedTarget ? .focusContinueExtra : .focusContinue)
                }
                .buttonStyle(.quiet)
            }
            .padding(.bottom, 36)
        }
        .padding(.horizontal, 24)
        .onAppear { appeared = true }
        .sensoryFeedback(summary.reachedTarget ? .success : .impact, trigger: appeared)
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
            .foregroundStyle(.white.opacity(0.75))
        case .free:
            if summary.reachedTarget {
                Label {
                    Text(status.isFreeForToday ? .focusLockFreeToday : .focusLockOpen)
                } icon: {
                    Image(systemName: "lock.open.fill")
                }
                .font(.callout.weight(.semibold))
                .foregroundStyle(mood.accent)
            }
        }
    }
}
