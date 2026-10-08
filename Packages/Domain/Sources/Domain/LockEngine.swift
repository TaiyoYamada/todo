import Foundation

/// 保存済みのデータと現在時刻から、ロックの状態を計算する。
///
/// 状態を持たない純粋な計算にしてある。アプリ本体、ウィジェット、テストのどこから呼んでも、
/// 同じ入力には同じ答えを返す。
public struct LockEngine: Sendable {
    public var calendar: Calendar

    /// 次のロックを探すときに、何日先まで見るか。
    private static let lookaheadDays = 7

    public init(calendar: Calendar) {
        self.calendar = calendar
    }

    public func status(world: World, now: Date) -> LockStatus {
        let clock = DayClock(calendar: calendar, dayStartHour: world.preferences.dayStartHour)
        let today = clock.day(containing: now)

        let goals = todaysGoals(world: world, clock: clock, today: today, now: now)
        let goalReasons = goals.compactMap { progress -> LockReason? in
            guard let startsAt = progress.lockStartsAt, !progress.isComplete else { return nil }
            return LockReason(
                source: .goal(progress.id),
                title: progress.goal.title,
                startsAt: startsAt,
                remainingSeconds: progress.remainingSeconds
            )
        }
        let factor = world.estimateFactor
        let taskReasons = world.openTasks.map { task in
            LockReason(
                source: .task(task.id),
                title: task.title,
                startsAt: task.startLimit(factor: factor),
                dueAt: task.dueAt
            )
        }

        let reasons = (goalReasons + taskReasons).sorted(by: Self.inOrder)
        let active = reasons.filter { $0.startsAt <= now }
        let upcoming = reasons.filter { $0.startsAt > now }

        let passUntil = world.passUses
            .filter { $0.usedAt <= now && now < $0.endsAt }
            .map(\.endsAt)
            .max()
        let week = clock.week(containing: now)
        let passesUsed = world.passUses.count(where: { week.start <= $0.usedAt && $0.usedAt < week.end })

        let phase: LockStatus.Phase
        if active.isEmpty {
            let laterGoalLock = nextGoalLock(after: today, world: world, clock: clock)
            phase = .free(nextLockAt: [upcoming.first?.startsAt, laterGoalLock].compactMap(\.self).min())
        } else if let passUntil {
            phase = .onPass(until: passUntil)
        } else {
            phase = .locked
        }

        return LockStatus(
            now: now,
            today: today,
            phase: phase,
            goals: goals,
            activeReasons: active,
            upcomingReasons: upcoming,
            forecast: forecast(goals: goals, world: world, today: today, now: now),
            passesRemaining: max(0, world.preferences.weeklyPassLimit - passesUsed),
            nextChangeAt: [upcoming.first?.startsAt, passUntil, today.end].compactMap(\.self).min()
        )
    }

    // MARK: - 目標

    private func todaysGoals(world: World, clock: DayClock, today: DateInterval, now: Date) -> [GoalProgress] {
        let weekday = clock.weekday(ofDayStarting: today.start)
        return world.activeGoals
            .filter { $0.weekdays.contains(weekday) && $0.dailyMinutes > 0 }
            .map { progress(of: $0, world: world, clock: clock, today: today, now: now) }
    }

    /// ある目標の今日の進み具合。今日が「やる曜日」でなくても計算できる(休みの日に自主的に進める場合)。
    public func progress(of goal: Goal, world: World, now: Date) -> GoalProgress {
        let clock = DayClock(calendar: calendar, dayStartHour: world.preferences.dayStartHour)
        return progress(of: goal, world: world, clock: clock, today: clock.day(containing: now), now: now)
    }

    private func progress(
        of goal: Goal,
        world: World,
        clock: DayClock,
        today: DateInterval,
        now: Date
    ) -> GoalProgress {
        let recorded = world.sessions
            .filter { $0.goalID == goal.id && today.start <= $0.startedAt && $0.startedAt < today.end }
            .reduce(0) { $0 + $1.seconds }
        // 計測中のぶんも数える。止めなくても、今日の分に達した時点でロックが外れるようにするため。
        var running = 0
        if let focus = world.activeFocus, focus.goalID == goal.id {
            running = max(0, Int(now.timeIntervalSince(max(focus.startedAt, today.start))))
        }
        let isScheduledToday = goal.weekdays.contains(clock.weekday(ofDayStarting: today.start))
        return GoalProgress(
            goal: goal,
            doneSeconds: recorded + running,
            recordedSeconds: recorded,
            lockStartsAt: isScheduledToday ? lockStart(of: goal, inDayStarting: today.start, clock: clock) : nil
        )
    }

    /// その日に、目標がロックの理由になり始める時刻。その日はロックしないなら nil。
    private func lockStart(of goal: Goal, inDayStarting dayStart: Date, clock: DayClock) -> Date? {
        // 作った当日はロックしない。登録した瞬間にスマホが止まると、最初の体験が罰になってしまう。
        guard goal.createdAt < dayStart else { return nil }
        switch goal.lockStart {
        case .dayStart:
            return dayStart
        case let .timeOfDay(minutes):
            return clock.time(minutesFromMidnight: minutes, inDayStarting: dayStart)
        }
    }

    /// 明日以降で、最初に目標がロックの理由になる時刻。
    private func nextGoalLock(after today: DateInterval, world: World, clock: DayClock) -> Date? {
        for offset in 1 ... Self.lookaheadDays {
            let dayStart = clock.offset(today.start, days: offset)
            let weekday = clock.weekday(ofDayStarting: dayStart)
            let earliest = world.activeGoals
                .filter { $0.weekdays.contains(weekday) && $0.dailyMinutes > 0 }
                .compactMap { lockStart(of: $0, inDayStarting: dayStart, clock: clock) }
                .min()
            if let earliest { return earliest }
        }
        return nil
    }

    // MARK: - ロック予報

    private func forecast(goals: [GoalProgress], world: World, today: DateInterval, now: Date) -> [ForecastEntry] {
        let goalEntries = goals.compactMap { progress -> ForecastEntry? in
            guard let at = progress.lockStartsAt else { return nil }
            return ForecastEntry(
                source: .goal(progress.id),
                title: progress.goal.title,
                at: at,
                state: progress.isComplete ? .cleared : (at <= now ? .active : .upcoming)
            )
        }
        let factor = world.estimateFactor
        let taskEntries = world.tasks.compactMap { task -> ForecastEntry? in
            let at = task.startLimit(factor: factor)
            if task.isOpen {
                // 今日のうちに着手リミットが来るものと、すでに過ぎているもの。
                guard at < today.end else { return nil }
                return ForecastEntry(
                    source: .task(task.id),
                    title: task.title,
                    at: at,
                    state: at <= now ? .active : .upcoming
                )
            }
            // 今日片づけたものは、済んだ印として残す。
            guard let completedAt = task.completedAt, today.contains(completedAt), completedAt < today.end else {
                return nil
            }
            return ForecastEntry(source: .task(task.id), title: task.title, at: at, state: .cleared)
        }
        return (goalEntries + taskEntries).sorted { ($0.at, $0.title) < ($1.at, $1.title) }
    }

    private static func inOrder(_ lhs: LockReason, _ rhs: LockReason) -> Bool {
        (lhs.startsAt, lhs.title) < (rhs.startsAt, rhs.title)
    }
}
