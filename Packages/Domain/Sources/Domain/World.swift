import Foundation

/// ロックの判定と画面の表示に必要な、保存済みデータのすべて。
///
/// データ量は小さい(目標とタスクは数十件、記録は直近のぶんだけ)ので、
/// 変更のたびに丸ごと読み直して各画面に配る。
public struct World: Equatable, Sendable {
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
}
