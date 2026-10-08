import AppFeature
import SwiftUI

@main
struct TodoApp: App {
    var body: some Scene {
        WindowGroup {
            RootView(sampleScenario: Self.sampleScenario)
        }
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
