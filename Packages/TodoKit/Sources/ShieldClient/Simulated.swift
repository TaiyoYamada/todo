import ConcurrencyExtras
import Domain
import Foundation
import OSLog

public extension ShieldClient {
    /// 模擬の実装。実際には何もロックせず、状態を覚えて記録に出すだけ。
    ///
    /// シミュレータではスクリーンタイム API が動かないので、画面の流れを確かめるために使う。
    static func simulated() -> ShieldClient {
        let state = LockIsolated((authorization: ShieldAuthorization.notDetermined, selectionCount: 0, isLocked: false))
        return ShieldClient(
            authorization: { state.value.authorization },
            requestAuthorization: {
                state.withValue {
                    $0.authorization = .approved
                    // 許可と同時に、いくつか選んだことにする。
                    $0.selectionCount = 6
                }
                return .approved
            },
            selectionCount: { state.value.selectionCount },
            apply: { plan, _ in
                let changed = state.withValue { current -> Bool in
                    defer { current.isLocked = plan.isLocked }
                    return current.isLocked != plan.isLocked
                }
                if changed {
                    logger
                        .info(
                            "模擬のロック: \(plan.isLocked ? "掛けた" : "外した", privacy: .public) \(plan.title ?? "", privacy: .public)"
                        )
                }
            }
        )
    }
}

private let logger = Logger(subsystem: "com.taiyoyamada.todo", category: "Shield")
