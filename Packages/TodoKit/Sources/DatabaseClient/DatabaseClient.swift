import Dependencies
import DependenciesMacros
import Domain
import Foundation

/// 保存データの読み書きの窓口。
///
/// 画面のロジックはこの型だけを知っていて、中身が SQLite であることは知らない。
/// テストでは必要な操作だけを差し替える。
@DependencyClient
public struct DatabaseClient: Sendable {
    /// 保存データ全体の流れ。購読した時点の値をまず流し、以後は変更のたびに流す。
    public var observeWorld: @Sendable () -> AsyncStream<World> = { .finished }

    public var saveGoal: @Sendable (_ goal: Goal) async throws -> Void
    public var deleteGoal: @Sendable (_ id: Goal.ID) async throws -> Void

    public var saveTask: @Sendable (_ task: TaskItem) async throws -> Void
    public var deleteTask: @Sendable (_ id: TaskItem.ID) async throws -> Void

    public var addSession: @Sendable (_ session: FocusSession) async throws -> Void
    public var setActiveFocus: @Sendable (_ focus: ActiveFocus?) async throws -> Void
    public var addPassUse: @Sendable (_ passUse: PassUse) async throws -> Void
    public var savePreferences: @Sendable (_ preferences: Preferences) async throws -> Void

    /// 保存データをすべて置き換える。見本データの投入と、テストの準備に使う。
    public var replaceAll: @Sendable (_ world: World) async throws -> Void
}

extension DatabaseClient: TestDependencyKey {
    public static let testValue = DatabaseClient()
    public static let previewValue = DatabaseClient.inMemory()
}

extension DependencyValues {
    public var database: DatabaseClient {
        get { self[DatabaseClient.self] }
        set { self[DatabaseClient.self] = newValue }
    }
}
