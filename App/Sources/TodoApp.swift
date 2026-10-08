import AppFeature
import SwiftUI
#if DEV && DEBUG
    import WidgetUI
#endif

@main
struct TodoApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEV && DEBUG
                if Self.sampleTab == "widgets" {
                    // ウィジェットの見た目を並べた、開発用の画面。
                    WidgetGallery(worlds: SampleWorlds.all)
                } else {
                    RootView(sampleScenario: Self.sampleScenario, initialTab: Self.sampleTab)
                }
            #else
                RootView(sampleScenario: Self.sampleScenario, initialTab: Self.sampleTab)
            #endif
        }
    }

    /// 起動引数 `-sampleTab <タブ>` で、最初に開くタブを選ぶ。画面の撮影用で、開発用の構成でだけ有効。
    private static var sampleTab: String? {
        #if DEV
            UserDefaults.standard.string(forKey: "sampleTab")
        #else
            nil
        #endif
    }

    /// 起動引数 `-sampleData <状態>` で、見本データに切り替える。
    /// 開発用の構成でだけ有効。本番のビルドでは常に nil になる。
    private static var sampleScenario: String? {
        #if DEV
            UserDefaults.standard.string(forKey: "sampleData")
        #else
            nil
        #endif
    }
}
