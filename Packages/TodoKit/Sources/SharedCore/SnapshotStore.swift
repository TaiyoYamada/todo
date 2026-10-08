import Domain
import Foundation

/// 保存データの写し。拡張機能は、データベースを開かずにこれを読む。
///
/// スクリーンタイムの拡張機能は使えるメモリがごく小さいので、
/// 必要な分だけを 1 つの小さなファイルにして渡す。
public struct Snapshot: Equatable, Sendable, Codable {
    public var world: World
    public var savedAt: Date

    public init(world: World, savedAt: Date) {
        self.world = world
        self.savedAt = savedAt
    }
}

public enum SnapshotStore {
    private static let fileName = "snapshot.json"

    /// 写しに残す記録の範囲。ロックの判定に要るのは今日のぶんだけなので、余裕を見て直近 2 日ぶん。
    private static let sessionWindow: TimeInterval = 2 * 24 * 3600

    private static var fileURL: URL? {
        AppGroup.containerURL?.appendingPathComponent(fileName)
    }

    /// 写しを書き出す。App Group が使えない環境では何もしない。
    @discardableResult
    public static func save(_ world: World, now: Date) -> Bool {
        guard let fileURL else { return false }
        var trimmed = world
        trimmed.sessions = world.sessions.filter { $0.startedAt >= now.addingTimeInterval(-sessionWindow) }
        // 片づいたタスクは、見積もりの癖の計算に使う直近のぶんだけ残す。
        let closed = world.tasks
            .filter { !$0.isOpen }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            .prefix(EstimateCalibration.window + 10)
        trimmed.tasks = world.openTasks + closed
        do {
            let data = try JSONEncoder().encode(Snapshot(world: trimmed, savedAt: now))
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    public static func load() -> Snapshot? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }
}
