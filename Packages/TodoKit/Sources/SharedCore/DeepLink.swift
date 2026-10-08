import Foundation

/// アプリの外(ウィジェット、コントロールセンター)から、アプリの特定の場面を開くための行き先。
public enum DeepLink: Equatable, Sendable {
    /// いちばん先にやるべきものの計測を始める。
    case focus
    /// タスクの追加を開く。
    case addTask

    /// URL スキーム。Info.plist の `AppURLScheme` から読む(開発用と本番用で違うため)。
    public static let scheme: String = Bundle.main.object(forInfoDictionaryKey: "AppURLScheme") as? String ?? "lockcast"

    public init?(url: URL) {
        switch url.host() {
        case "focus": self = .focus
        case "add-task": self = .addTask
        default: return nil
        }
    }

    public var url: URL {
        let host =
            switch self {
            case .focus: "focus"
            case .addTask: "add-task"
            }
        // スキームとホストは固定の文字列なので、必ず URL になる。
        return URL(string: "\(Self.scheme)://\(host)") ?? URL(fileURLWithPath: "/")
    }
}
