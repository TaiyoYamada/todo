import ActivityKit
import Dependencies
import DependenciesMacros
import Domain
import Foundation
import OSLog
import SharedCore

/// 集中の計測を Live Activity として出す窓口。
@DependencyClient
public struct LiveActivityClient: Sendable {
    public var start: @Sendable (_ goal: Goal, _ startedAt: Date, _ endsAt: Date?) async -> Void
    public var end: @Sendable () async -> Void
}

extension LiveActivityClient: DependencyKey {
    public static let liveValue = LiveActivityClient(
        start: { goal, startedAt, endsAt in
            // 前の計測の表示が残っていれば、先に片づける。
            await endAll()
            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                logger.info("Live Activity は無効(利用者の設定)")
                return
            }
            let attributes = FocusActivityAttributes(
                goalTitle: goal.title,
                symbol: goal.symbol,
                tint: goal.tint.rawValue
            )
            let state = FocusActivityAttributes.ContentState(startedAt: startedAt, endsAt: endsAt)
            // 失敗しても計測そのものには影響しないので、記録に残すだけにする。
            do {
                _ = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: state, staleDate: endsAt),
                    pushType: nil
                )
            } catch {
                logger.error("Live Activity を始められなかった: \(error.localizedDescription, privacy: .public)")
            }
        },
        end: { await endAll() }
    )

    /// 表示は補助的なもので、失敗しても計測には影響しない。
    /// テストとプレビューでは何もしない実装にして、各テストが差し替えなくて済むようにする。
    public static let testValue = LiveActivityClient(start: { _, _, _ in }, end: {})
    public static let previewValue = testValue

    private static func endAll() async {
        for activity in Activity<FocusActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

public extension DependencyValues {
    var liveActivity: LiveActivityClient {
        get { self[LiveActivityClient.self] }
        set { self[LiveActivityClient.self] = newValue }
    }
}

private let logger = Logger(subsystem: "com.taiyoyamada.todo", category: "LiveActivity")
