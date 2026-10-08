import Dependencies
import Domain
import Foundation
import SharedCore

extension ShieldClient: DependencyKey {
    public static let liveValue: ShieldClient = {
        #if canImport(FamilyControls) && !targetEnvironment(simulator)
            return .screenTime()
        #else
            return .simulated()
        #endif
    }()
}

#if canImport(FamilyControls) && canImport(ManagedSettings) && canImport(DeviceActivity) && !targetEnvironment(simulator)
    import FamilyControls

    extension ShieldClient {
        /// スクリーンタイム API を使う本物の実装。
        ///
        /// 注意: 動作は未検証。実機と Family Controls の権限が必要。
        static func screenTime() -> ShieldClient {
            ShieldClient(
                authorization: { await currentAuthorization() },
                requestAuthorization: {
                    try? await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                    return await currentAuthorization()
                },
                selectionCount: { SelectionStore.count },
                apply: { plan, world in
                    let now = Date()
                    // 拡張機能が読む写しを先に更新する。予約の時刻に起こされたとき、最新の状況で判定できるように。
                    SnapshotStore.save(world, now: now)
                    ShieldApplier.apply(isLocked: plan.isLocked)
                    MonitorScheduler.reschedule(plan: plan, world: world, now: now)
                }
            )
        }

        @MainActor
        private static func currentAuthorization() -> ShieldAuthorization {
            switch AuthorizationCenter.shared.authorizationStatus {
            case .approved: .approved
            case .denied: .denied
            case .notDetermined: .notDetermined
            @unknown default: .notDetermined
            }
        }
    }
#endif
