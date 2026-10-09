import ComposableArchitecture
import DesignSystem
import Domain
import SwiftUI

/// 「今日」の画面。次のロックまでの余裕を、錠前のキャラクターと大きな数字で見せる。
///
/// 単色、太い枠、沈むボタンで作る。質感(グラデーションやガラス)ではなく、動きで楽しく見せる。
struct TodayView: View {
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
                if !laterTasks.isEmpty {
                    PlayfulLaterTasks(tasks: laterTasks, world: world, now: status.now, send: { store.send($0) })
                        .entrance(appeared, order: 3)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(Playful.background.ignoresSafeArea())
        .onAppear { appeared = true }
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
            .accessibilityIdentifier("today.add")

            Button {
                store.send(.settingsTapped)
            } label: {
                Image(systemName: "gearshape.fill")
            }
            .buttonStyle(.chunkyIcon(Playful.neutral))
            .accessibilityLabel(Text(.todaySettings))
            .accessibilityIdentifier("today.settings")
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
            SpeechBubble {
                Text(line)
                    .accessibilityIdentifier(identifier)
            }
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

    /// UI テストが、いまの状態を見分けるための名前。
    private var identifier: String {
        switch hero {
        case .empty: "today.hero.empty"
        case .locked: "today.hero.locked"
        case .onPass: "today.hero.onPass"
        case .countdown: "today.hero.countdown"
        case .freeToday: "today.hero.free"
        }
    }

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
            .accessibilityIdentifier("today.hero.addGoal")

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
                .accessibilityIdentifier("today.hero.startFocus")
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
            .accessibilityIdentifier("today.hero.startFocus")

        case let .task(id):
            if let startedAt = world.task(id: id)?.startedAt {
                // 取りかかったあとは、経過時間を見せながら、終わったら押せるようにしておく。
                Label {
                    HStack(spacing: 6) {
                        Text(.todayTaskWorking)
                        Text(startedAt, style: .timer)
                    }
                } icon: {
                    Image(systemName: "figure.run")
                }
                .font(.system(.footnote, design: .rounded, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(tone.face)
                Button {
                    tap(.completeTaskTapped(id))
                } label: {
                    Label { Text(.todayCtaCompleteTask) } icon: { Image(systemName: "checkmark") }
                }
                .buttonStyle(.chunky(tone))
                .accessibilityIdentifier("today.hero.completeTask")
            } else {
                Button {
                    tap(.startTaskTapped(id))
                } label: {
                    Label { Text(.todayCtaStartTask) } icon: { Image(systemName: "play.fill") }
                }
                .buttonStyle(.chunky(tone))
                .accessibilityIdentifier("today.hero.startTask")
                Button {
                    tap(.completeTaskTapped(id))
                } label: {
                    Text(.todayCtaAlreadyDone)
                }
                .buttonStyle(.chunkySecondary)
                .accessibilityIdentifier("today.hero.completeTask")
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
