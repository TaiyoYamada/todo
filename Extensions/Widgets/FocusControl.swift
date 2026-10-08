import AppIntents
import SwiftUI
import WidgetKit

// このファイルは、パッケージ(WidgetUI)ではなく拡張機能の側に置く。
// App Intents の名前は、ビルド時に文字列リテラルから読み取られ、拡張機能自身の文言カタログで訳される。
// パッケージの中に置くと、その仕組みに乗らない。
// ボタンが呼ぶ `StartFocusIntent` は Extensions/Shared にある。

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
