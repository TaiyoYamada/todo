import ComposableArchitecture
import DesignSystem
import Domain
import SwiftUI

// 「今日」の画面の下半分。今日のロック予報、これからの7日、この先の締切。

// MARK: - 今日のロック予報

struct PlayfulTimeline: View {
    let items: [TimelineItem]
    let dayStart: Date
    let send: (TodayFeature.Action) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.todayForecastTitle)
                .chunkyHeading()
                .accessibilityIdentifier("today.forecast.title")
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    PlayfulTimelineRow(item: item, isFromMorning: item.at == dayStart, send: send)
                    if index < items.count - 1 {
                        Rectangle()
                            .fill(Playful.line)
                            .frame(height: 2)
                            .padding(.vertical, 12)
                    }
                }
            }
            .chunkyCard()
            // カードに付けた識別子が、中の行やボタンの識別子を上書きしないようにする。
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("today.forecast")
            // 並び順が変わるとき(片づいて下へ移るとき)に、行が弾んで入れ替わる。
            .animation(.spring(duration: 0.5, bounce: 0.3), value: items.map(\.id))
        }
    }
}

private struct PlayfulTimelineRow: View {
    let item: TimelineItem
    let isFromMorning: Bool
    let send: (TodayFeature.Action) -> Void

    private var isCleared: Bool { item.state == .cleared }

    var body: some View {
        HStack(spacing: 12) {
            time
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(item.state == .active ? Playful.coral.face : Playful.subtext)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: 64, alignment: .leading)

            Button(action: open) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(item.title)
                        .font(.system(.body, design: .rounded, weight: .heavy))
                        .foregroundStyle(Playful.text)
                        .strikethrough(isCleared, color: Playful.subtext)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    detail
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .opacity(isCleared ? 0.5 : 1)
            // 行の識別子は、入れ物ではなく、この実体のあるボタンに付ける。
            // 入れ物に付けると、行が1つだけのときに、外側のカードの識別子に上書きされて消える。
            .accessibilityIdentifier("today.item.\(item.title)")

            action
        }
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

    @ViewBuilder
    private var detail: some View {
        switch item.kind {
        case let .goal(progress):
            ChunkyProgressBar(fraction: progress.fraction, tone: progress.goal.tint.tone)
            Text(
                item.state == .optional
                    ? .todayGoalsNoLockToday
                    : .todayGoalsProgress(
                        DurationText.compact(minutes: progress.doneSeconds / 60),
                        DurationText.compact(minutes: progress.goal.dailyMinutes)
                    )
            )
            .font(.system(.caption, design: .rounded, weight: .bold))
            .foregroundStyle(Playful.subtext)
            .monospacedDigit()
        case let .task(task):
            Text(.todayTasksDue(TimeText.dayAndClock(task.dueAt)))
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(Playful.subtext)
        }
    }

    @ViewBuilder
    private var action: some View {
        switch item.kind {
        case let .goal(progress):
            Button {
                send(.startFocusTapped(progress.id))
            } label: {
                Image(systemName: isCleared ? "checkmark" : "play.fill")
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.chunkyIcon(isCleared ? Playful.neutral : progress.goal.tint.tone))
            .accessibilityLabel(Text(.todayCtaStartFocus(progress.goal.title)))
            .accessibilityIdentifier("today.start.\(progress.goal.title)")
        case let .task(task):
            if isCleared {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Playful.subtext)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            } else {
                Button {
                    send(.completeTaskTapped(task.id))
                } label: {
                    Image(systemName: "checkmark")
                }
                .buttonStyle(.chunkyIcon(Playful.neutral))
                .accessibilityLabel(Text(.todayCtaCompleteTask))
                .accessibilityRemoveTraits(.isSelected)
                .accessibilityIdentifier("today.complete.\(task.title)")
            }
        }
    }

    private func open() {
        switch item.kind {
        case let .goal(progress): send(.goalTapped(progress.id))
        case let .task(task): send(.taskTapped(task.id))
        }
    }
}

// MARK: - これからの7日

struct PlayfulWeek: View {
    let days: [DayOutlook]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.todayWeekTitle)
                .chunkyHeading()
                .accessibilityIdentifier("today.week.title")
            HStack(spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                    cell(day, isToday: index == 0)
                }
            }
        }
    }

    private func cell(_ day: DayOutlook, isToday: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return VStack(spacing: 6) {
            Group {
                if isToday {
                    Text(.commonToday)
                } else {
                    Text(day.dayStart, format: .dateTime.weekday(.abbreviated))
                }
            }
            .font(.system(.caption2, design: .rounded, weight: .heavy))
            .foregroundStyle(isToday ? Playful.text : Playful.subtext)
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            Image(systemName: symbol(for: day.severity))
                .font(.title3)
                .foregroundStyle(color(for: day.severity))
                .frame(height: 24)
                .accessibilityHidden(true)

            Group {
                if let first = day.firstLockAt {
                    if first == day.dayStart {
                        Text(.todayForecastFromMorning)
                    } else {
                        Text(TimeText.clock(first))
                    }
                } else {
                    Text(verbatim: "–")
                }
            }
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(Playful.subtext)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity)
        .background(Playful.surface, in: shape)
        .overlay { shape.strokeBorder(isToday ? Playful.text : Playful.line, lineWidth: 2) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(day.dayStart, format: .dateTime.weekday(.wide).month().day()))
    }

    private func symbol(for severity: DayOutlook.Severity) -> String {
        switch severity {
        case .clear: "sun.max.fill"
        case .routine: "cloud.sun.fill"
        case .deadline: "cloud.fill"
        case .heavy: "cloud.bolt.fill"
        }
    }

    /// 単色で塗る。多色の記号は、この流儀の平らな見た目に合わない。
    private func color(for severity: DayOutlook.Severity) -> Color {
        switch severity {
        case .clear: Playful.amber.face
        case .routine: Playful.mint.face
        case .deadline: Playful.sky.face
        case .heavy: Playful.coral.face
        }
    }
}

// MARK: - この先の締切

struct PlayfulLaterTasks: View {
    let tasks: [TaskItem]
    let world: World
    let now: Date
    let send: (TodayFeature.Action) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.todayTasksLaterTitle)
                .chunkyHeading()
                .accessibilityIdentifier("today.tasks.title")
            VStack(spacing: 0) {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    row(task)
                    if index < tasks.count - 1 {
                        Rectangle()
                            .fill(Playful.line)
                            .frame(height: 2)
                            .padding(.vertical, 12)
                    }
                }
            }
            .chunkyCard()
        }
    }

    private func row(_ task: TaskItem) -> some View {
        let limit = world.startLimit(of: task)
        return HStack(spacing: 12) {
            Button {
                send(.taskTapped(task.id))
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.system(.body, design: .rounded, weight: .heavy))
                        .foregroundStyle(Playful.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(.todayTasksDue(TimeText.dayAndClock(task.dueAt)))
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(Playful.subtext)
                    Label {
                        Text(.todayTasksStartLimit(TimeText.dayAndClock(limit)))
                    } icon: {
                        Image(systemName: limit <= now ? "lock.fill" : "lock.open")
                    }
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .foregroundStyle(limit <= now ? Playful.coral.face : Playful.text)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Button {
                send(.completeTaskTapped(task.id))
            } label: {
                Image(systemName: "checkmark")
            }
            .buttonStyle(.chunkyIcon(Playful.neutral))
            .accessibilityLabel(Text(.todayCtaCompleteTask))
            .accessibilityRemoveTraits(.isSelected)
            .accessibilityIdentifier("today.task.complete")
        }
    }
}
