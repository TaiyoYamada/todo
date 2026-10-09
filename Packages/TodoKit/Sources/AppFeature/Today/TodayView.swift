import ComposableArchitecture
import DesignSystem
import Domain
import SwiftUI

/// 「今日」の画面の、もう1つの作り方。
///
/// 単色、太い枠、沈むボタン、錠前のキャラクターで作る。質感(グラデーションやガラス)ではなく、
/// 動きで楽しく見せる。ロジックは `TodayFeature` をそのまま使い、見た目だけが違う。
struct PlayfulTodayView: View {
    let store: StoreOf<TodayFeature>
    @Dependency(\.calendar) private var calendar
    @State private var appeared = false

    var body: some View {
        let status = store.board.status
        let world = store.board.world
        let items = TodayTimeline.items(status: status, world: world)

        ScrollView {
            VStack(spacing: 22) {
                header(status)
                PlayfulHero(
                    hero: store.hero,
                    status: status,
                    world: world,
                    suggestedGoal: status.goals.first { !$0.isComplete },
                    calendar: calendar,
                    send: { store.send($0) }
                )
                if !items.isEmpty {
                    PlayfulTimeline(items: items, dayStart: status.today.start, send: { store.send($0) })
                        .entrance(appeared, order: 1)
                }
                if store.hero != .empty {
                    PlayfulWeek(days: LockEngine(calendar: calendar).weekOutlook(world: world, now: status.now))
                        .entrance(appeared, order: 2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Playful.background.ignoresSafeArea())
        .onAppear { appeared = true }
    }

    private func header(_ status: LockStatus) -> some View {
        HStack(spacing: 10) {
            Text(status.today.start, format: .dateTime.month().day().weekday(.wide))
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(Playful.subtext)
            Spacer()
            Menu {
                Button {
                    store.send(.addGoalTapped)
                } label: {
                    Label { Text(.todayAddGoal) } icon: { Image(systemName: "target") }
                }
                Button {
                    store.send(.addTaskTapped)
                } label: {
                    Label { Text(.todayAddTask) } icon: { Image(systemName: "calendar.badge.clock") }
                }
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.chunkyIcon(Playful.neutral))
            .accessibilityLabel(Text(.commonAdd))

            Button {
                store.send(.settingsTapped)
            } label: {
                Image(systemName: "gearshape.fill")
            }
            .buttonStyle(.chunkyIcon(Playful.neutral))
            .accessibilityLabel(Text(.todaySettings))
        }
        .padding(.top, 8)
    }
}

private extension View {
    /// 画面が出たときに、順番に下から弾んで入ってくる。
    func entrance(_ appeared: Bool, order: Int) -> some View {
        opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 28)
            .animation(.spring(duration: 0.55, bounce: 0.35).delay(0.08 * Double(order)), value: appeared)
    }
}

// MARK: - いちばん上(キャラクターとせりふ)

private struct PlayfulHero: View {
    let hero: Hero
    let status: LockStatus
    let world: World
    let suggestedGoal: GoalProgress?
    let calendar: Calendar
    let send: (TodayFeature.Action) -> Void

    @State private var taps = 0

    var body: some View {
        VStack(spacing: 14) {
            LockMascot(mood: mood, tone: tone)
            SpeechBubble { Text(line) }
            headline
            actions
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .sensoryFeedback(.impact(weight: .medium), trigger: taps)
        .sensoryFeedback(.success, trigger: hero) { old, new in
            // ロックが外れた瞬間に、手応えを返す。
            if case .locked = old, case .locked = new { return false }
            if case .locked = old { return true }
            return false
        }
    }

    // MARK: 状態から決まるもの

    private var isSoon: Bool {
        if case let .countdown(until, _) = hero { return until.timeIntervalSince(status.now) < 3600 }
        return false
    }

    private var tone: PlayfulTone {
        switch hero {
        case .empty: Playful.sky
        case .locked: Playful.coral
        case .onPass: Playful.amber
        case .countdown: isSoon ? Playful.amber : Playful.mint
        case .freeToday: Playful.mint
        }
    }

    private var mood: LockMascot.Mood {
        switch hero {
        case .empty: .happy
        case .locked: .locked
        case .onPass: .watching
        case .countdown: isSoon ? .nervous : .calm
        case .freeToday: .sleepy
        }
    }

    /// キャラクターのせりふ。いまの状況を、ひとことで言う。
    private var line: LocalizedStringResource {
        switch hero {
        case .empty:
            return .mascotEmpty
        case let .locked(primary, _):
            if let remaining = primary.remainingSeconds {
                return .mascotLockedGoal(primary.title, DurationText.compact(seconds: remaining))
            }
            if case let .task(id) = primary.source, world.task(id: id)?.startedAt != nil {
                return .mascotLockedTaskStarted(primary.title)
            }
            return .mascotLockedTask(primary.title)
        case .onPass:
            return .mascotPass
        case let .countdown(until, reason):
            let title = reason?.title ?? ""
            return isSoon
                ? .mascotCountdownSoon(TimeText.clock(until), title)
                : .mascotCountdown(TimeText.clock(until), title)
        case let .freeToday(nextLockAt):
            if let nextLockAt, nextLockAt.timeIntervalSince(status.now) < 24 * 3600 {
                return .mascotFreeNext(TimeText.clock(nextLockAt))
            }
            return .mascotFree
        }
    }

    // MARK: 大きな数字

    @ViewBuilder
    private var headline: some View {
        switch hero {
        case let .countdown(until, _), let .onPass(until, _):
            VStack(spacing: 2) {
                Text(hero.isOnPass ? .todayPassLabel : .todaySlackLabel)
                    .chunkyHeading()
                Text(timerInterval: status.now ... max(until, status.now), countsDown: true)
                    .font(.hero(64))
                    .monospacedDigit()
                    .foregroundStyle(Playful.text)
                    .contentTransition(.numericText(countsDown: true))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        case let .locked(_, others) where others > 0:
            Text(.todayLockedMore(others))
                .chunkyHeading()
        default:
            EmptyView()
        }
    }

    // MARK: 操作

    @ViewBuilder
    private var actions: some View {
        switch hero {
        case .empty:
            Button {
                tap(.addGoalTapped)
            } label: {
                Text(.todayAddGoal)
            }
            .buttonStyle(.chunky(tone))

        case let .locked(primary, _):
            reasonAction(primary)
            outlook(resolving: primary.source)
            if status.passesRemaining > 0 {
                HoldToConfirmButton(tint: tone.face) {
                    tap(.usePassConfirmed)
                } label: {
                    Text(.todayPassButton(status.passesRemaining))
                        .foregroundStyle(Playful.text)
                }
            } else {
                Text(.todayPassNone)
                    .chunkyHeading()
            }

        case let .onPass(_, primary):
            reasonAction(primary)

        case .countdown, .freeToday:
            if let suggestedGoal {
                Button {
                    tap(.startFocusTapped(suggestedGoal.id))
                } label: {
                    Label {
                        Text(
                            .todayCtaAdvance(
                                suggestedGoal.goal.title,
                                DurationText.compact(seconds: suggestedGoal.remainingSeconds)
                            )
                        )
                    } icon: {
                        Image(systemName: "play.fill")
                    }
                }
                .buttonStyle(.chunky(tone))
                outlook(resolving: .goal(suggestedGoal.id))
            }
        }
    }

    @ViewBuilder
    private func reasonAction(_ reason: LockReason) -> some View {
        switch reason.source {
        case let .goal(id):
            Button {
                tap(.startFocusTapped(id))
            } label: {
                Label {
                    Text(.todayCtaAdvance(reason.title, DurationText.compact(seconds: reason.remainingSeconds ?? 0)))
                } icon: {
                    Image(systemName: "play.fill")
                }
            }
            .buttonStyle(.chunky(tone))

        case let .task(id):
            if world.task(id: id)?.startedAt != nil {
                Button {
                    tap(.completeTaskTapped(id))
                } label: {
                    Label { Text(.todayCtaCompleteTask) } icon: { Image(systemName: "checkmark") }
                }
                .buttonStyle(.chunky(tone))
            } else {
                Button {
                    tap(.startTaskTapped(id))
                } label: {
                    Label { Text(.todayCtaStartTask) } icon: { Image(systemName: "play.fill") }
                }
                .buttonStyle(.chunky(tone))
                Button {
                    tap(.completeTaskTapped(id))
                } label: {
                    Text(.todayCtaAlreadyDone)
                }
                .buttonStyle(.chunky(Playful.neutral))
            }
        }
    }

    /// 「これを終えると、次のロックはいつになるか」。
    @ViewBuilder
    private func outlook(resolving source: LockReason.Source) -> some View {
        let preview = LockEngine(calendar: calendar).preview(resolving: source, world: world, now: status.now)
        if preview.unlocks {
            Group {
                if preview.isFreeForToday {
                    Text(.todayOutlookFree)
                } else if let nextLockAt = preview.nextLockAt {
                    Text(.todayOutlookNext(TimeText.clock(nextLockAt)))
                }
            }
            .font(.system(.footnote, design: .rounded, weight: .bold))
            .foregroundStyle(Playful.subtext)
            .multilineTextAlignment(.center)
        }
    }

    private func tap(_ action: TodayFeature.Action) {
        taps += 1
        send(action)
    }
}

private extension Hero {
    var isOnPass: Bool {
        if case .onPass = self { true } else { false }
    }
}

// MARK: - 今日のロック予報

private struct PlayfulTimeline: View {
    let items: [TimelineItem]
    let dayStart: Date
    let send: (TodayFeature.Action) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.todayForecastTitle)
                .chunkyHeading()
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

            action
        }
        .accessibilityElement(children: .contain)
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

private struct PlayfulWeek: View {
    let days: [DayOutlook]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.todayWeekTitle)
                .chunkyHeading()
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
