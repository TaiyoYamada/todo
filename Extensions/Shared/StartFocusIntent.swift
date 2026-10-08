import AppIntents
import SharedCore

// このファイルは、アプリ本体とウィジェットの拡張機能の両方に入れる。
// アプリを開く App Intent は、開かれる側のアプリにも定義がないと働かないため。

/// アプリを開いて、いちばん先にやるべきものの計測を始める。
struct StartFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "control.focus.title"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        // 行き先を共有の置き場に書いておき、開いたアプリがそれを読む。
        PendingDeepLink.set(.focus)
        return .result()
    }
}
