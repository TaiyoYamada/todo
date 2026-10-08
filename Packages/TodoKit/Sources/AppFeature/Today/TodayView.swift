import ComposableArchitecture
import DesignSystem
import Domain
import SwiftUI

struct TodayView: View {
    let store: StoreOf<TodayFeature>
    @Dependency(\.calendar) private var calendar

    var body: some View {
        let status = store.board.status
        let mood = Mood(hero: store.hero, status: status)

        ScrollView {
            VStack(spacing: 20) {
                header
                HeroView(
                    hero: store.hero,
                    status: status,
                    world: store.board.world,
                    suggestedGoal: status.goals.first { !$0.isComplete },
                    onStartFocus: { store.send(.startFocusTapped($0)) },
                    onCompleteTask: { store.send(.completeTaskTapped($0)) },
                    onUsePass: { store.send(.usePassConfirmed) },
                    onAddGoal: { store.send(.addGoalTapped) }
                )
                let items = TodayTimeline.items(status: status, world: store.board.world)
                if !items.isEmpty {
                    TimelineCard(
                        items: items,
                        dayStart: status.today.start,
                        onStartFocus: { store.send(.startFocusTapped($0)) },
                        onCompleteTask: { store.send(.completeTaskTapped($0)) },
                        onOpenGoal: { store.send(.goalTapped($0)) },
                        onOpenTask: { store.send(.taskTapped($0)) }
                    )
                }
                if store.hero != .empty {
                    WeekOutlookCard(
                        days: LockEngine(calendar: calendar).weekOutlook(world: store.board.world, now: status.now)
                    )
                }
                if !laterTasks.isEmpty {
                    TasksCard(
                        tasks: laterTasks,
                        world: store.board.world,
                        now: status.now,
                        onComplete: { store.send(.completeTaskTapped($0)) },
                        onOpen: { store.send(.taskTapped($0)) }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background { AuroraBackground(mood: mood) }
        .environment(\.mood, mood)
        .animation(.smooth(duration: 0.5), value: store.hero)
    }

    private var header: some View {
        HStack {
            Text(store.board.status.today.start, format: .dateTime.month().day().weekday(.wide))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
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
                    .font(.body.weight(.semibold))
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel(Text(.commonAdd))
            Button {
                store.send(.settingsTapped)
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.body)
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel(Text(.todaySettings))
        }
        .foregroundStyle(.white)
        .padding(.top, 8)
    }

    /// 明日以降に着手リミットが来るタスク。今日のぶんはロック予報に出ているので、ここには出さない。
    /// 多すぎると読まれないので、近いものから数件だけ。
    private var laterTasks: [TaskItem] {
        let world = store.board.world
        let todayEnd = store.board.status.today.end
        return Array(
            world.openTasks
                .filter { world.startLimit(of: $0) >= todayEnd }
                .sorted { world.startLimit(of: $0) < world.startLimit(of: $1) }
                .prefix(4)
        )
    }
}

extension Mood {
    /// いまの状態に合う雰囲気。ロックが近づくほど、色で緊張を伝える。
    init(hero: Hero, status: LockStatus) {
        switch hero {
        case .empty:
            self = .calm
        case .locked:
            self = .locked
        case .onPass:
            self = .warning
        case let .countdown(until, _):
            self = until.timeIntervalSince(status.now) < 3600 ? .warning : .calm
        case .freeToday:
            self = .free
        }
    }
}

// MARK: - いちばん上の表示

private struct HeroView: View {
    let hero: Hero
    let status: LockStatus
    let world: World
    let suggestedGoal: GoalProgress?
    let onStartFocus: (Goal.ID) -> Void
    let onCompleteTask: (TaskItem.ID) -> Void
    let onUsePass: () -> Void
    let onAddGoal: () -> Void

    @Environment(\.mood) private var mood
    @Dependency(\.calendar) private var calendar

    var body: some View {
        VStack(spacing: 14) {
            switch hero {
            case .empty:
                label(.todayEmptyLabel, symbol: "sparkles")
                Text(.todayEmptyHeadline)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                Text(.todayEmptyBody)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                Button(action: onAddGoal) {
                    Text(.todayAddGoal)
                }
                .buttonStyle(.hero)
                .padding(.top, 6)

            case let .locked(primary, others):
                label(.todayLockedLabel, symbol: "lock.fill")
                Text(primary.title)
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                Text(hint(for: primary))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                if others > 0 {
                    Text(.todayLockedMore(others))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                action(for: primary)
                    .padding(.top, 6)
                passButton

            case let .onPass(until, primary):
                label(.todayPassLabel, symbol: "hourglass")
                countdown(to: until)
                Text(.todayPassHint)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                action(for: primary)
                    .padding(.top, 6)

            case let .countdown(until, reason):
                label(.todaySlackLabel, symbol: "timer")
                countdown(to: until)
                if let reason {
                    Text(.todaySlackReason(TimeText.clock(until), reason.title))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                suggestion
                    .padding(.top, 6)

            case let .freeToday(nextLockAt):
                label(.todayFreeLabel, symbol: "checkmark.seal.fill")
                Text(.todayFreeHeadline)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                if let nextLockAt {
                    // 24 時間以内なら時刻だけを出す。深夜に「今日はもうない/次は今日 4:00」と矛盾して見えるのを避ける。
                    Text(
                        nextLockAt.timeIntervalSince(status.now) < 24 * 3600
                            ? .todayFreeNextTime(TimeText.clock(nextLockAt))
                            : .todayFreeNext(TimeText.dayAndClock(nextLockAt))
                    )
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white.opacity(0.75))
                }
                suggestion
                    .padding(.top, 6)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private func label(_ text: LocalizedStringResource, symbol: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: symbol)
        }
        .font(.footnote.weight(.bold))
        .textCase(.uppercase)
        .kerning(1.2)
        .foregroundStyle(mood.accent)
        .padding(.vertical, 7)
        .padding(.horizontal, 14)
        .background(mood.accent.opacity(0.16), in: .capsule)
    }

    /// 残り時間。OS が毎秒描き直すので、状態を毎秒更新しなくてよい。
    private func countdown(to date: Date) -> some View {
        Text(timerInterval: status.now...max(date, status.now), countsDown: true)
            .font(.system(size: 76, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .contentTransition(.numericText(countsDown: true))
            .shadow(color: mood.accent.opacity(0.5), radius: 24)
            .accessibilityLabel(Text(.todaySlackLabel))
    }

    private func hint(for reason: LockReason) -> LocalizedStringResource {
        if let remaining = reason.remainingSeconds {
            .todayLockedGoalHint(DurationText.compact(seconds: remaining))
        } else {
            .todayLockedTaskHint
        }
    }

    @ViewBuilder
    private func action(for reason: LockReason) -> some View {
        switch reason.source {
        case let .goal(id):
            Button {
                onStartFocus(id)
            } label: {
                Label {
                    Text(.todayCtaAdvance(reason.title, DurationText.compact(seconds: reason.remainingSeconds ?? 0)))
                } icon: {
                    Image(systemName: "play.fill")
                }
            }
            .buttonStyle(.hero)

        case let .task(id):
            Button {
                onCompleteTask(id)
            } label: {
                Label { Text(.todayCtaCompleteTask) } icon: { Image(systemName: "checkmark") }
            }
            .buttonStyle(.hero)
        }
        outlook(resolving: reason.source)
    }

    /// 「これを終えると、次のロックはいつになるか」。いま動く理由を、具体的な時刻で見せる。
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
            .font(.footnote.weight(.semibold))
            .foregroundStyle(mood.accent)
            .multilineTextAlignment(.center)
        }
    }

    /// ロックされていないときの提案。まだ終えていない今日の分があれば、先に進めるよう促す。
    @ViewBuilder
    private var suggestion: some View {
        if let suggestedGoal {
            Button {
                onStartFocus(suggestedGoal.id)
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
            .buttonStyle(.hero)
            outlook(resolving: .goal(suggestedGoal.id))
        }
    }

    @ViewBuilder
    private var passButton: some View {
        if status.passesRemaining > 0 {
            HoldToConfirmButton(tint: mood.accent, action: onUsePass) {
                Text(.todayPassButton(status.passesRemaining))
            }
        } else {
            Text(.todayPassNone)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.55))
                .padding(.top, 4)
        }
    }
}

// MARK: - この先の締切

private struct TasksCard: View {
    let tasks: [TaskItem]
    let world: World
    let now: Date
    let onComplete: (TaskItem.ID) -> Void
    let onOpen: (TaskItem.ID) -> Void

    @Environment(\.mood) private var mood

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(.todayTasksLaterTitle)
                .sectionLabelStyle()
            ForEach(tasks) { task in
                let limit = world.startLimit(of: task)
                HStack(spacing: 14) {
                    Button {
                        onComplete(task.id)
                    } label: {
                        Image(systemName: "circle")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(Text(.todayCtaCompleteTask))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.title)
                            .font(.body.weight(.semibold))
                            .lineLimit(2)
                        Text(.todayTasksDue(TimeText.dayAndClock(task.dueAt)))
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.65))
                        Label {
                            Text(.todayTasksStartLimit(TimeText.dayAndClock(limit)))
                        } icon: {
                            Image(systemName: limit <= now ? "lock.fill" : "lock.open")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(limit <= now ? mood.accent : .white.opacity(0.75))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                    .onTapGesture { onOpen(task.id) }
                }
            }
        }
        .foregroundStyle(.white)
        .glassCard()
    }
}
