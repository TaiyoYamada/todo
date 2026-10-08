import AppIntents
import SharedCore
import SwiftUI
import WidgetKit

// このファイルだけは、パッケージ(WidgetUI)ではなく拡張機能の側に置く。
// App Intents の名前は、ビルド時に文字列リテラルから読み取られ、拡張機能自身の文言カタログで訳される。
// パッケージの中に置くと、その仕組みに乗らない。

/// コントロールセンター、ロック画面、アクションボタンに置けるボタン。押すと、計測を始める画面が開く。
struct FocusControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "FocusControl") {
            ControlWidgetButton(action: StartFocusIntent()) {
                Label("control.focus.title", systemImage: "play.circle.fill")
            }
        }
        .displayName("control.focus.title")
        .description("control.focus.description")
    }
}

/// アプリを開いて、いちばん先にやるべきものの計測を始める。
struct StartFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "control.focus.title"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(DeepLink.focus.url))
    }
}
