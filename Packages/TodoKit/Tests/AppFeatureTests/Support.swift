import ComposableArchitecture
import DatabaseClient
import Domain
import Foundation
@testable import AppFeature

// MARK: - 日時と ID

/// テスト用の暦。東京時間のグレゴリオ暦に固定して、実行する場所で結果が変わらないようにする。
let tokyo: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    guard let timeZone = TimeZone(identifier: "Asia/Tokyo") else {
        preconditionFailure("東京のタイムゾーンが見つからない")
    }
    calendar.timeZone = timeZone
    return calendar
}()

/// 2026年10月の日時を作る。10/9 は金曜日。
func date(_ day: Int, _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0) -> Date {
    let components = DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute, second: second)
    guard let date = tokyo.date(from: components) else {
        preconditionFailure("日時を作れない: \(components)")
    }
    return date
}

/// `UUIDGenerator.incrementing` が作る ID と同じ並び(0 から)。
func uuid(_ value: Int) -> UUID {
    guard let uuid = UUID(uuidString: "00000000-0000-0000-0000-" + String(format: "%012d", value)) else {
        preconditionFailure("ID を作れない: \(value)")
    }
    return uuid
}

// MARK: - データ

extension Goal {
    /// 前日に作った目標。作った当日はロックしない規則を避けるため。
    static func fixture(
        _ id: Int = 1,
        title: String = "院試",
        dailyMinutes: Int = 30,
        weekdays: Set<Weekday> = Weekday.everyDay,
        lockStart: LockStart = .dayStart,
        createdAt: Date = date(8, 12)
    ) -> Goal {
        Goal(
            id: uuid(id),
            title: title,
            dailyMinutes: dailyMinutes,
            weekdays: weekdays,
            lockStart: lockStart,
            createdAt: createdAt
        )
    }
}

extension TaskItem {
    static func fixture(
        _ id: Int = 100,
        title: String = "レポート",
        dueAt: Date = date(9, 23, 59),
        estimateMinutes: Int = 120,
        startedAt: Date? = nil,
        actualMinutes: Int? = nil,
        completedAt: Date? = nil,
        withdrawnAt: Date? = nil
    ) -> TaskItem {
        TaskItem(
            id: uuid(id),
            title: title,
            dueAt: dueAt,
            estimateMinutes: estimateMinutes,
            startedAt: startedAt,
            actualMinutes: actualMinutes,
            completedAt: completedAt,
            withdrawnAt: withdrawnAt,
            createdAt: date(8, 12)
        )
    }
}

extension FocusSession {
    static func fixture(_ id: Int = 200, goal: Int = 1, startedAt: Date, minutes: Int) -> FocusSession {
        FocusSession(id: uuid(id), goalID: uuid(goal), startedAt: startedAt, seconds: minutes * 60)
    }
}

extension World {
    /// 見積もりどおりの倍率(1.0)に固定し、初回設定を済ませた World。時刻の計算を追いやすくするため。
    static func exact(
        goals: [Goal] = [],
        tasks: [TaskItem] = [],
        sessions: [FocusSession] = [],
        passUses: [PassUse] = [],
        activeFocus: ActiveFocus? = nil,
        weeklyPassLimit: Int = 2
    ) -> World {
        World(
            goals: goals,
            tasks: tasks,
            sessions: sessions,
            passUses: passUses,
            activeFocus: activeFocus,
            preferences: Preferences(buffer: .none, weeklyPassLimit: weeklyPassLimit, hasCompletedOnboarding: true)
        )
    }
}

// MARK: - 共有の状態

extension Board {
    /// 保存データを読み終え、`now` の時点でロックの状態を計算し終えた Board。
    static func loaded(_ world: World, now: Date) -> Board {
        Board(world: world, status: LockEngine(calendar: tokyo).status(world: world, now: now), isLoaded: true)
    }
}

/// 各画面が読む共有の Board を、指定した状態にする。`TestStore` を作る前に呼ぶ。
///
/// 本番では `AppFeature` だけが書き込む。子の画面のテストでは、その代わりをここで行う。
@discardableResult
func prepareBoard(_ world: World, now: Date) -> Shared<Board> {
    @Shared(.board) var board
    $board.withLock { $0 = .loaded(world, now: now) }
    return $board
}

// MARK: - 依存の差し替え

/// 保存の呼び出しを、順番どおりに覚えておく。
///
/// 「何を」「どの順で」保存したかを、そのまま比べられるようにする。
final class DatabaseSpy: Sendable {
    enum Write: Equatable, Sendable {
        case saveGoal(Goal)
        case deleteGoal(Goal.ID)
        case saveTask(TaskItem)
        case deleteTask(TaskItem.ID)
        case addSession(FocusSession)
        case setActiveFocus(ActiveFocus?)
        /// 計測の終了。記録を足すのと、計測中の印を消すのを、1回の書き込みで行う。
        case finishFocus([FocusSession])
        case addPassUse(PassUse)
        case savePreferences(Preferences)
    }

    private let recorded = LockIsolated<[Write]>([])

    var writes: [Write] { recorded.value }

    /// 呼び出しを覚えるだけの `DatabaseClient`。監視(`observeWorld`)は何も流さない。
    var client: DatabaseClient {
        DatabaseClient(
            observeWorld: { .finished },
            saveGoal: { [recorded] goal in recorded.withValue { $0.append(.saveGoal(goal)) } },
            deleteGoal: { [recorded] id in recorded.withValue { $0.append(.deleteGoal(id)) } },
            saveTask: { [recorded] task in recorded.withValue { $0.append(.saveTask(task)) } },
            deleteTask: { [recorded] id in recorded.withValue { $0.append(.deleteTask(id)) } },
            addSession: { [recorded] session in recorded.withValue { $0.append(.addSession(session)) } },
            setActiveFocus: { [recorded] focus in recorded.withValue { $0.append(.setActiveFocus(focus)) } },
            finishFocus: { [recorded] sessions in recorded.withValue { $0.append(.finishFocus(sessions)) } },
            addPassUse: { [recorded] passUse in recorded.withValue { $0.append(.addPassUse(passUse)) } },
            savePreferences: { [recorded] preferences in
                recorded.withValue { $0.append(.savePreferences(preferences)) }
            },
            replaceAll: { _ in }
        )
    }
}

extension DependencyValues {
    /// 時刻、ID、暦、保存先を固定する。テストが実際の時刻や保存データに触れないようにするため。
    ///
    /// - Parameter now: 途中で時刻を進めたいときは、`LockIsolated` の値を書き換える。
    mutating func fix(now: LockIsolated<Date>, database: DatabaseSpy) {
        date = DateGenerator { now.value }
        uuid = .incrementing
        calendar = tokyo
        self.database = database.client
    }

    /// 画面を閉じる依頼を数える。
    mutating func countDismiss(into count: LockIsolated<Int>) {
        dismiss = DismissEffect { count.withValue { $0 += 1 } }
    }
}

extension TestStore {
    /// 終わりのない処理(定期的な見直しの予約など)が残るテストの最後に呼ぶ。
    ///
    /// ここまでは厳密に確かめたうえで、残っている処理は追わずに打ち切る。
    @MainActor
    func cancelRemainingEffects() async {
        exhaustivity = .off
        await skipInFlightEffects(strict: false)
    }
}
