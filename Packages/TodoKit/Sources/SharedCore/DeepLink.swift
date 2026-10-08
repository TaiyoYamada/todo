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

/// 拡張機能からアプリへ渡す、開いてほしい行き先。
///
/// コントロールセンターのボタンは、アプリを開くことはできるが、行き先までは渡せない。
/// そこで共有の置き場に書いておき、開いたアプリが読んで消す。
public enum PendingDeepLink {
    private static let key = "pendingDeepLink"

    public static func set(_ link: DeepLink) {
        AppGroup.defaults?.set(link.url.absoluteString, forKey: key)
    }

    /// 書かれていれば取り出して消す。
    public static func take() -> DeepLink? {
        guard let defaults = AppGroup.defaults, let value = defaults.string(forKey: key) else { return nil }
        defaults.removeObject(forKey: key)
        return URL(string: value).flatMap(DeepLink.init(url:))
    }
}
