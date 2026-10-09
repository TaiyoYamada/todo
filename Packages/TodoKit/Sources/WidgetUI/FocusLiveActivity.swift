import ActivityKit
import DesignSystem
import Domain
import SharedCore
import SwiftUI
import WidgetKit

/// 集中の計測中に、ロック画面と Dynamic Island へ残り時間を出す。
public struct FocusLiveActivity: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            LockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let tint = Self.color(context.attributes)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.attributes.symbol)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(tint)
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Clock(state: context.state)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(tint)
                        .frame(maxWidth: 96, alignment: .trailing)
                        .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.goalTitle)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Bar(state: context.state, tint: tint)
                        .padding(.horizontal, 6)
                }
            } compactLeading: {
                Image(systemName: context.attributes.symbol)
                    .foregroundStyle(tint)
            } compactTrailing: {
                Clock(state: context.state)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: context.attributes.symbol)
                    .foregroundStyle(tint)
            }
            .keylineTint(tint)
        }
    }

    static func color(_ attributes: FocusActivityAttributes) -> Color {
        (Goal.Tint(rawValue: attributes.tint) ?? .indigo).color
    }
}

private struct LockScreenView: View {
    let attributes: FocusActivityAttributes
    let state: FocusActivityAttributes.ContentState

    var body: some View {
        let tint = FocusLiveActivity.color(attributes)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: attributes.symbol)
                    .font(.headline)
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.2), in: .circle)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(attributes.goalTitle)
                        .font(.headline)
                        .lineLimit(1)
                    Text(state.endsAt == nil ? .activityCaptionExtra : .activityCaptionRemaining)
                        .font(.caption)
                        .foregroundStyle(Playful.subtext)
                }
                Spacer(minLength: 8)
                Clock(state: state)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(tint)
                    .frame(maxWidth: 130, alignment: .trailing)
            }
            Bar(state: state, tint: tint)
        }
        .foregroundStyle(Playful.text)
        .padding(16)
    }
}

/// 今日の分までは残り時間を、達したあとは経過時間を出す。OS が毎秒描き直す。
private struct Clock: View {
    let state: FocusActivityAttributes.ContentState

    var body: some View {
        Group {
            if let endsAt = state.endsAt {
                Text(timerInterval: state.startedAt ... max(endsAt, state.startedAt), countsDown: true)
            } else {
                Text(state.startedAt, style: .timer)
            }
        }
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

private struct Bar: View {
    let state: FocusActivityAttributes.ContentState
    let tint: Color

    var body: some View {
        if let endsAt = state.endsAt {
            ProgressView(timerInterval: state.startedAt ... max(endsAt, state.startedAt), countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(tint)
        }
    }
}
