import DesignSystem
import Domain
import SwiftUI

/// 今日のロック予報。時刻順に、何がいつロックの理由になるかと、その場でできる操作を並べる。
struct TimelineCard: View {
    let items: [TimelineItem]
    let dayStart: Date
    let onStartFocus: (Goal.ID) -> Void
    let onCompleteTask: (TaskItem.ID) -> Void
    let onOpenGoal: (Goal.ID) -> Void
    let onOpenTask: (TaskItem.ID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(.todayForecastTitle)
                .sectionLabelStyle()
                .accessibilityIdentifier("today.forecast.title")
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    TimelineRow(
                        item: item,
                        isFromMorning: item.at == dayStart,
                        isLast: index == items.count - 1,
                        onStartFocus: onStartFocus,
                        onCompleteTask: onCompleteTask,
                        onOpenGoal: onOpenGoal,
                        onOpenTask: onOpenTask
                    )
                }
            }
        }
        .foregroundStyle(.white)
        .glassCard()
        .accessibilityIdentifier("today.forecast")
    }
}

private struct TimelineRow: View {
    let item: TimelineItem
    let isFromMorning: Bool
    let isLast: Bool
    let onStartFocus: (Goal.ID) -> Void
    let onCompleteTask: (TaskItem.ID) -> Void
    let onOpenGoal: (Goal.ID) -> Void
    let onOpenTask: (TaskItem.ID) -> Void

    @Environment(\.mood) private var mood

    private var isCleared: Bool { item.state == .cleared }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            time
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(isCleared ? 0.4 : 0.85))
                // 英語の「5:26 AM」が折り返さない幅にする。
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: 68, alignment: .leading)
                .padding(.top, 11)

            // 時刻順に印を縦線でつなぎ、1日の流れとして見せる。
            VStack(spacing: 4) {
                marker
                    .frame(width: 44, height: 44)
                if !isLast {
                    Rectangle()
                        .fill(.white.opacity(0.14))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }

            Button(action: open) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.body.weight(.semibold))
                        .strikethrough(isCleared, color: .white.opacity(0.5))
                        .foregroundStyle(.white.opacity(isCleared ? 0.5 : 1))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    detail
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(isCleared ? 0.4 : 0.65))
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.bottom, isLast ? 0 : 16)

            action
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("today.item.\(item.title)")
    }

    @ViewBuilder
    private var time: some View {
        if let at = item.at {
            if isFromMorning {
                Text(.todayForecastFromMorning)
            } else {
                Text(TimeText.clock(at))
            }
        } else {
            Text(verbatim: "–")
        }
    }

    /// 行の印。目標は進み具合の輪、タスクは状態の記号。
    @ViewBuilder
    private var marker: some View {
        switch item.kind {
        case let .goal(progress):
            ProgressRing(fraction: progress.fraction, lineWidth: 4, tint: progress.goal.tint.color) {
                Image(systemName: progress.isComplete ? "checkmark" : progress.goal.symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(progress.goal.tint.color)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
            }
            .padding(4)
        case .task:
            Image(systemName: taskSymbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(item.state == .active ? mood.accent : .white.opacity(isCleared ? 0.4 : 0.8))
                .accessibilityHidden(true)
        }
    }

    private var taskSymbol: String {
        switch item.state {
        case .cleared: "checkmark.circle.fill"
        case .active: "lock.circle.fill"
        case .upcoming, .optional: "calendar.badge.clock"
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch item.kind {
        case let .goal(progress):
            if item.state == .optional {
                Text(.todayGoalsNoLockToday)
            } else {
                Text(
                    .todayGoalsProgress(
                        DurationText.compact(minutes: progress.doneSeconds / 60),
                        DurationText.compact(minutes: progress.goal.dailyMinutes)
                    )
                )
            }
        case let .task(task):
            Text(.todayTasksDue(TimeText.dayAndClock(task.dueAt)))
        }
    }

    /// その場でできる操作。目標は計測の開始、タスクは完了。片づいたタスクには出さない。
    @ViewBuilder
    private var action: some View {
        switch item.kind {
        case let .goal(progress):
            Button {
                onStartFocus(progress.id)
            } label: {
                Image(systemName: "play.fill")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(progress.goal.tint.color.opacity(isCleared ? 0.16 : 0.34), in: .circle)
            }
            .accessibilityLabel(Text(.todayCtaStartFocus(progress.goal.title)))
            .accessibilityIdentifier("today.start.\(progress.goal.title)")
        case let .task(task):
            if !isCleared {
                Button {
                    onCompleteTask(task.id)
                } label: {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.14), in: .circle)
                }
                .accessibilityLabel(Text(.todayCtaCompleteTask))
                .accessibilityIdentifier("today.complete.\(task.title)")
            }
        }
    }

    private func open() {
        switch item.kind {
        case let .goal(progress): onOpenGoal(progress.id)
        case let .task(task): onOpenTask(task.id)
        }
    }
}
