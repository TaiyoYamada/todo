import Dependencies
import DependenciesMacros
import Domain
import Foundation
import SharedCore
import WidgetKit

/// 拡張機能(ウィジェット、スクリーンタイム)に、いまの保存データを渡す窓口。
@DependencyClient
public struct SnapshotClient: Sendable {
    /// 写しを書き出し、ウィジェットに描き直しを頼む。
    public var save: @Sendable (_ world: World) async -> Void
}

extension SnapshotClient: DependencyKey {
    public static let liveValue = SnapshotClient(
        save: { world in
            SnapshotStore.save(world, now: Date())
            WidgetCenter.shared.reloadAllTimelines()
        }
    )

    /// 写しは拡張機能のためのもので、画面のロジックの結果には影響しない。
    /// テストとプレビューでは何もしない実装にして、各テストが差し替えなくて済むようにする。
    public static let testValue = SnapshotClient(save: { _ in })
    public static let previewValue = testValue
}

extension DependencyValues {
    public var snapshot: SnapshotClient {
        get { self[SnapshotClient.self] }
        set { self[SnapshotClient.self] = newValue }
    }
}
