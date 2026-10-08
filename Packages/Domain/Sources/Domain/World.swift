import Foundation

/// ロックの判定と画面の表示に必要な、保存済みデータのすべて。
///
/// データ量は小さい(目標とタスクは数十件、記録は直近のぶんだけ)ので、
/// 変更のたびに丸ごと読み直して各画面に配る。
public struct World: Equatable, Sendable, Codable {
    public var goals: [Goal]
    public var tasks: [TaskItem]
    public var sessions: [FocusSession]
    public var passUses: [PassUse]
    public var activeFocus: ActiveFocus?
    public var preferences: Preferences

    public init(
        goals: [Goal] = [],
        tasks: [TaskItem] = [],
        sessions: [FocusSession] = [],
        passUses: [PassUse] = [],
        activeFocus: ActiveFocus? = nil,
        preferences: Preferences = Preferences()
    ) {
        self.goals = goals
        self.tasks = tasks
        self.sessions = sessions
        self.passUses = passUses
        self.activeFocus = activeFocus
        self.preferences = preferences
    }

    public var activeGoals: [Goal] { goals.filter { !$0.isArchived } }
    public var openTasks: [TaskItem] { tasks.filter(\.isOpen) }

    public func goal(id: Goal.ID) -> Goal? { goals.first { $0.id == id } }
    public func task(id: TaskItem.ID) -> TaskItem? { tasks.first { $0.id == id } }

    /// 見積もりの癖。完了したタスクの「見積もり」と「実際」から求める。
    public var calibration: EstimateCalibration { EstimateCalibration(tasks: tasks) }

    /// 着手リミットを決めるときに、見積もりへ掛ける倍率。
    public var estimateFactor: Double {
        preferences.buffer.fixedFactor ?? calibration.factor
    }

    public func startLimit(of task: TaskItem) -> Date {
        task.startLimit(factor: estimateFactor)
    }
}
