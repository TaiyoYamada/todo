import Foundation

/// ロックの理由。目標の今日の分が残っている、またはタスクの着手リミットを過ぎた。
public struct LockReason: Identifiable, Equatable, Sendable {
    public enum Source: Hashable, Sendable {
        case goal(Goal.ID)
        case task(TaskItem.ID)
    }

    public var source: Source
    public var title: String
    /// この時刻からロックの理由になる。
    public var startsAt: Date
    /// 目標の場合の、今日の分の残り(秒)。
    public var remainingSeconds: Int?
    /// タスクの場合の締切。
    public var dueAt: Date?

    public var id: Source { source }

    public init(
        source: Source,
        title: String,
        startsAt: Date,
        remainingSeconds: Int? = nil,
        dueAt: Date? = nil
    ) {
        self.source = source
        self.title = title
        self.startsAt = startsAt
        self.remainingSeconds = remainingSeconds
        self.dueAt = dueAt
    }
}

/// ある目標の、今日の進み具合。
public struct GoalProgress: Identifiable, Equatable, Sendable {
    public var goal: Goal
    /// 今日やった量(秒)。計測中のぶんを含む。
    public var doneSeconds: Int
    /// 今日やった量のうち、記録として保存済みのぶん(秒)。
    public var recordedSeconds: Int
    /// 今日この目標がロックの理由になる時刻。作った当日はロックしないので nil。
    public var lockStartsAt: Date?

    public var id: Goal.ID { goal.id }
    public var targetSeconds: Int { goal.dailySeconds }
    public var remainingSeconds: Int { max(0, targetSeconds - doneSeconds) }
    public var isComplete: Bool { doneSeconds >= targetSeconds }
    public var fraction: Double {
        targetSeconds == 0 ? 1 : min(1, Double(doneSeconds) / Double(targetSeconds))
    }

    public init(goal: Goal, doneSeconds: Int, recordedSeconds: Int, lockStartsAt: Date?) {
        self.goal = goal
        self.doneSeconds = doneSeconds
        self.recordedSeconds = recordedSeconds
        self.lockStartsAt = lockStartsAt
    }
}

/// ロック予報の1行。今日のうちに、何がいつロックの理由になるか。
public struct ForecastEntry: Identifiable, Equatable, Sendable {
    public enum State: Equatable, Sendable {
        /// もう片づいた。
        case cleared
        /// いまロックの理由になっている。
        case active
        /// これからロックの理由になる。
        case upcoming
    }

    public var source: LockReason.Source
    public var title: String
    public var at: Date
    public var state: State

    public var id: LockReason.Source { source }

    public init(source: LockReason.Source, title: String, at: Date, state: State) {
        self.source = source
        self.title = title
        self.at = at
        self.state = state
    }
}

/// ある時点でのロックの状態。`LockEngine` が計算する。
public struct LockStatus: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        /// ロック中。
        case locked
        /// ロックの理由はあるが、パスで一時的に外れている。
        case onPass(until: Date)
        /// ロックされていない。`nextLockAt` は次にロックが始まる時刻(予定がなければ nil)。
        case free(nextLockAt: Date?)
    }

    public var now: Date
    public var today: DateInterval
    public var phase: Phase
    /// 今日が「やる曜日」の目標。
    public var goals: [GoalProgress]
    /// いま有効なロックの理由。始まった順。
    public var activeReasons: [LockReason]
    /// これから始まるロックの理由。始まる順。今日の目標と、未完了のタスクすべて。
    public var upcomingReasons: [LockReason]
    public var forecast: [ForecastEntry]
    public var passesRemaining: Int
    /// 計測中の集中が、今日の分に達する時刻。計測していないか、もう達していれば nil。
    public var focusTargetAt: Date?
    /// 時間の経過だけで状態が変わりうる、次の時刻。表示の更新や予約に使う。
    public var nextChangeAt: Date?

    public var isLocked: Bool { phase == .locked }

    /// 次のロックまでの余裕(秒)。ロック中、または予定がなければ nil。
    public var slack: TimeInterval? {
        switch phase {
        case .locked: nil
        case let .onPass(until): until.timeIntervalSince(now)
        case let .free(nextLockAt): nextLockAt.map { $0.timeIntervalSince(now) }
        }
    }

    /// 今日はもうロックの予定がない。
    public var isFreeForToday: Bool {
        guard case let .free(nextLockAt) = phase else { return false }
        return nextLockAt.map { $0 >= today.end } ?? true
    }

    /// パスを使えるか。ロック中で、今週の回数が残っているときだけ。
    public var canUsePass: Bool { isLocked && passesRemaining > 0 }
}
