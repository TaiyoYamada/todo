import Foundation

/// アプリ本体と拡張機能(ウィジェット、スクリーンタイム)が共有する置き場。
///
/// 識別子は Info.plist の `AppGroupIdentifier` から読む。開発用と本番用で値が違うため、
/// コードには直接書かない。
public enum AppGroup {
    public static let identifier: String? = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String

    /// 共有フォルダ。App Group が使えない環境(設定漏れなど)では nil。
    public static var containerURL: URL? {
        identifier.flatMap { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) }
    }

    public static var defaults: UserDefaults? {
        identifier.flatMap { UserDefaults(suiteName: $0) }
    }
}
