import Dependencies
import DependenciesMacros
import Domain
import Foundation

/// スクリーンタイムの利用許可の状態。
public enum ShieldAuthorization: Equatable, Sendable {
    case notDetermined
    case approved
    case denied
}

/// アプリをロックする仕組み(スクリーンタイム API)との境界。
///
/// 実機では本物の API を、シミュレータでは模擬の実装を使う。
/// 画面のロジックは、どちらが動いているかを知らない。
@DependencyClient
public struct ShieldClient: Sendable {
    public var authorization: @Sendable () async -> ShieldAuthorization = { .notDetermined }
    /// 利用の許可を求める。OS の確認画面が出る。
    public var requestAuthorization: @Sendable () async -> ShieldAuthorization = { .denied }
    /// ロックの対象に選ばれているアプリとカテゴリの数。
    public var selectionCount: @Sendable () async -> Int = { 0 }
    /// いまの状況を伝える。ロックを掛けるか外すかと、次に見直す時刻の予約を行う。
    public var apply: @Sendable (_ plan: ShieldPlan, _ world: World) async -> Void
}

extension ShieldClient: TestDependencyKey {
    public static let testValue = ShieldClient()
    public static let previewValue = ShieldClient.simulated()
}

public extension DependencyValues {
    var shield: ShieldClient {
        get { self[ShieldClient.self] }
        set { self[ShieldClient.self] = newValue }
    }
}
