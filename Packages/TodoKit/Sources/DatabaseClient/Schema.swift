import Domain
import Foundation
import OSLog
import SQLiteData

// このファイルは SQLiteData だけを import する。
// GRDB にも `Table` や `Column` という名前があり、同じファイルで両方を読み込むと衝突するため。

// MARK: - 行の型

// 日時は 1970 年からの秒数(REAL)で持つ。文字列より比較が単純で、表現の違いに悩まされない。

@Table("goals")
struct GoalRecord: Sendable {
    let id: UUID
    var title: String
    var symbol: String
    var tint: String
    var dailyMinutes: Int
    /// 曜日の集合をビットで持つ。日曜が 1 << 1、土曜が 1 << 7。
    var weekdays: Int
    /// nil なら「朝から」。値があれば、その時刻(0 時からの分)からロックする。
    var lockStartMinutes: Int?
    var isArchived: Bool
    var createdAt: Double
}

@Table("tasks")
struct TaskRecord: Sendable {
    let id: UUID
    var title: String
    var dueAt: Double
    var estimateMinutes: Int
    var completedAt: Double?
    var withdrawnAt: Double?
    var createdAt: Double
}

@Table("sessions")
struct SessionRecord: Sendable {
    let id: UUID
    var goalID: UUID
    var startedAt: Double
    var seconds: Int
}

@Table("passUses")
struct PassUseRecord: Sendable {
    let id: UUID
    var usedAt: Double
    var minutes: Int
}

/// 1行だけの表。設定と、計測中の集中を持つ。
@Table("appState")
struct AppStateRecord: Sendable {
    static let rowID = 1

    let id: Int
    /// `Preferences` を JSON にしたもの。項目が増えても表の形を変えずに済む。
    var preferences: String
    var activeFocusGoalID: UUID?
    var activeFocusStartedAt: Double?
}

// MARK: - Domain の型との変換

extension GoalRecord {
    init(_ goal: Goal) {
        self.init(
            id: goal.id,
            title: goal.title,
            symbol: goal.symbol,
            tint: goal.tint.rawValue,
            dailyMinutes: goal.dailyMinutes,
            weekdays: goal.weekdays.reduce(0) { $0 | (1 << $1.rawValue) },
            lockStartMinutes: {
                if case let .timeOfDay(minutes) = goal.lockStart { minutes } else { nil }
            }(),
            isArchived: goal.isArchived,
            createdAt: goal.createdAt.timeIntervalSince1970
        )
    }

    var goal: Goal {
        Goal(
            id: id,
            title: title,
            symbol: symbol,
            tint: Goal.Tint(rawValue: tint) ?? .indigo,
            dailyMinutes: dailyMinutes,
            weekdays: Set(Weekday.allCases.filter { weekdays & (1 << $0.rawValue) != 0 }),
            lockStart: lockStartMinutes.map { .timeOfDay(minutes: $0) } ?? .dayStart,
            isArchived: isArchived,
            createdAt: Date(timeIntervalSince1970: createdAt)
        )
    }
}

extension TaskRecord {
    init(_ task: TaskItem) {
        self.init(
            id: task.id,
            title: task.title,
            dueAt: task.dueAt.timeIntervalSince1970,
            estimateMinutes: task.estimateMinutes,
            completedAt: task.completedAt?.timeIntervalSince1970,
            withdrawnAt: task.withdrawnAt?.timeIntervalSince1970,
            createdAt: task.createdAt.timeIntervalSince1970
        )
    }

    var task: TaskItem {
        TaskItem(
            id: id,
            title: title,
            dueAt: Date(timeIntervalSince1970: dueAt),
            estimateMinutes: estimateMinutes,
            completedAt: completedAt.map(Date.init(timeIntervalSince1970:)),
            withdrawnAt: withdrawnAt.map(Date.init(timeIntervalSince1970:)),
            createdAt: Date(timeIntervalSince1970: createdAt)
        )
    }
}

extension SessionRecord {
    init(_ session: FocusSession) {
        self.init(
            id: session.id,
            goalID: session.goalID,
            startedAt: session.startedAt.timeIntervalSince1970,
            seconds: session.seconds
        )
    }

    var session: FocusSession {
        FocusSession(id: id, goalID: goalID, startedAt: Date(timeIntervalSince1970: startedAt), seconds: seconds)
    }
}

extension PassUseRecord {
    init(_ passUse: PassUse) {
        self.init(id: passUse.id, usedAt: passUse.usedAt.timeIntervalSince1970, minutes: passUse.minutes)
    }

    var passUse: PassUse {
        PassUse(id: id, usedAt: Date(timeIntervalSince1970: usedAt), minutes: minutes)
    }
}

extension Preferences {
    var json: String {
        (try? String(data: JSONEncoder().encode(self), encoding: .utf8)) ?? "{}"
    }

    init(json: String) {
        self = (try? JSONDecoder().decode(Preferences.self, from: Data(json.utf8))) ?? Preferences()
    }
}

// MARK: - 接続と移行

/// アプリのデータベースを開き、表を最新の形にする。
///
/// 実行の文脈(本番、プレビュー、テスト)に合わせた場所に作られる。
/// プレビューとテストでは一時的なデータベースになり、本番のデータに触れない。
public func openAppDatabase() throws -> any DatabaseWriter {
    let database = try SQLiteData.defaultDatabase()
    logger.info("open \(database.path, privacy: .public)")
    try migrator.migrate(database)
    return database
}

private var migrator: DatabaseMigrator {
    var migrator = DatabaseMigrator()

    // 表の定義は SQL の文字列で書く。一度配布した移行は書き換えないので、
    // 型の変更に引きずられない形で固定しておく。
    migrator.registerMigration("v1: 最初の表") { db in
        try #sql(
            """
            CREATE TABLE "goals" (
              "id" TEXT PRIMARY KEY NOT NULL,
              "title" TEXT NOT NULL,
              "symbol" TEXT NOT NULL,
              "tint" TEXT NOT NULL,
              "dailyMinutes" INTEGER NOT NULL,
              "weekdays" INTEGER NOT NULL,
              "lockStartMinutes" INTEGER,
              "isArchived" INTEGER NOT NULL DEFAULT 0,
              "createdAt" REAL NOT NULL
            ) STRICT
            """
        )
        .execute(db)
        try #sql(
            """
            CREATE TABLE "tasks" (
              "id" TEXT PRIMARY KEY NOT NULL,
              "title" TEXT NOT NULL,
              "dueAt" REAL NOT NULL,
              "estimateMinutes" INTEGER NOT NULL,
              "completedAt" REAL,
              "withdrawnAt" REAL,
              "createdAt" REAL NOT NULL
            ) STRICT
            """
        )
        .execute(db)
        try #sql(
            """
            CREATE TABLE "sessions" (
              "id" TEXT PRIMARY KEY NOT NULL,
              "goalID" TEXT NOT NULL REFERENCES "goals"("id") ON DELETE CASCADE,
              "startedAt" REAL NOT NULL,
              "seconds" INTEGER NOT NULL
            ) STRICT
            """
        )
        .execute(db)
        try #sql(
            """
            CREATE INDEX "idx_sessions_goalID_startedAt" ON "sessions"("goalID", "startedAt")
            """
        )
        .execute(db)
        try #sql(
            """
            CREATE TABLE "passUses" (
              "id" TEXT PRIMARY KEY NOT NULL,
              "usedAt" REAL NOT NULL,
              "minutes" INTEGER NOT NULL
            ) STRICT
            """
        )
        .execute(db)
        try #sql(
            """
            CREATE TABLE "appState" (
              "id" INTEGER PRIMARY KEY NOT NULL CHECK ("id" = 1),
              "preferences" TEXT NOT NULL,
              "activeFocusGoalID" TEXT REFERENCES "goals"("id") ON DELETE SET NULL,
              "activeFocusStartedAt" REAL
            ) STRICT
            """
        )
        .execute(db)
        try #sql(
            """
            INSERT INTO "appState" ("id", "preferences") VALUES (1, '{}')
            """
        )
        .execute(db)
    }

    return migrator
}

// MARK: - 読み書き

/// 保存データをすべて読む。
func fetchWorld(_ db: Database) throws -> World {
    let state = try AppStateRecord.all.fetchOne(db)
    let activeFocus: ActiveFocus? =
        if let goalID = state?.activeFocusGoalID, let startedAt = state?.activeFocusStartedAt {
            ActiveFocus(goalID: goalID, startedAt: Date(timeIntervalSince1970: startedAt))
        } else {
            nil
        }
    return try World(
        goals: GoalRecord.order { $0.createdAt }.fetchAll(db).map(\.goal),
        tasks: TaskRecord.order { $0.dueAt }.fetchAll(db).map(\.task),
        sessions: SessionRecord.order { $0.startedAt }.fetchAll(db).map(\.session),
        passUses: PassUseRecord.order { $0.usedAt }.fetchAll(db).map(\.passUse),
        activeFocus: activeFocus,
        preferences: Preferences(json: state?.preferences ?? "{}")
    )
}

extension DatabaseClient {
    /// SQLite に保存する実装。
    public static func live(database: any DatabaseWriter) -> DatabaseClient {
        DatabaseClient(
            observeWorld: { observe(in: database, fetchWorld) },
            saveGoal: { goal in
                try await database.write { db in
                    try GoalRecord.upsert { GoalRecord(goal) }.execute(db)
                }
            },
            deleteGoal: { id in
                try await database.write { db in
                    try GoalRecord.where { $0.id.eq(id) }.delete().execute(db)
                }
            },
            saveTask: { task in
                try await database.write { db in
                    try TaskRecord.upsert { TaskRecord(task) }.execute(db)
                }
            },
            deleteTask: { id in
                try await database.write { db in
                    try TaskRecord.where { $0.id.eq(id) }.delete().execute(db)
                }
            },
            addSession: { session in
                try await database.write { db in
                    try SessionRecord.insert { SessionRecord(session) }.execute(db)
                }
            },
            setActiveFocus: { focus in
                try await database.write { db in
                    try AppStateRecord
                        .where { $0.id.eq(AppStateRecord.rowID) }
                        .update {
                            $0.activeFocusGoalID = focus?.goalID
                            $0.activeFocusStartedAt = focus?.startedAt.timeIntervalSince1970
                        }
                        .execute(db)
                }
            },
            addPassUse: { passUse in
                try await database.write { db in
                    try PassUseRecord.insert { PassUseRecord(passUse) }.execute(db)
                }
            },
            savePreferences: { preferences in
                try await database.write { db in
                    try AppStateRecord
                        .where { $0.id.eq(AppStateRecord.rowID) }
                        .update { $0.preferences = preferences.json }
                        .execute(db)
                }
            },
            replaceAll: { world in
                try await database.write { db in
                    try SessionRecord.delete().execute(db)
                    try PassUseRecord.delete().execute(db)
                    try TaskRecord.delete().execute(db)
                    try GoalRecord.delete().execute(db)
                    for goal in world.goals {
                        try GoalRecord.insert { GoalRecord(goal) }.execute(db)
                    }
                    for task in world.tasks {
                        try TaskRecord.insert { TaskRecord(task) }.execute(db)
                    }
                    for session in world.sessions {
                        try SessionRecord.insert { SessionRecord(session) }.execute(db)
                    }
                    for passUse in world.passUses {
                        try PassUseRecord.insert { PassUseRecord(passUse) }.execute(db)
                    }
                    try AppStateRecord
                        .where { $0.id.eq(AppStateRecord.rowID) }
                        .update {
                            $0.preferences = world.preferences.json
                            $0.activeFocusGoalID = world.activeFocus?.goalID
                            $0.activeFocusStartedAt = world.activeFocus?.startedAt.timeIntervalSince1970
                        }
                        .execute(db)
                }
            }
        )
    }
}

extension DatabaseClient: DependencyKey {
    public static let liveValue: DatabaseClient = {
        do {
            return try .live(database: openAppDatabase())
        } catch {
            // 開けなくてもアプリは起動させる。保存はされないが、落ちるよりは状況を伝えられる。
            reportIssue(error, "データベースを開けませんでした。メモリ上の保存に切り替えます。")
            return .inMemory()
        }
    }()
}

private let logger = Logger(subsystem: "com.taiyoyamada.todo", category: "Database")
