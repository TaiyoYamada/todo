import SwiftUI
import WidgetKit
import WidgetUI

/// ウィジェットの拡張機能の入口。中身は TodoKit の WidgetUI にある。
@main
struct WidgetsBundle: WidgetBundle {
    var body: some Widget {
        SlackWidget()
        FocusLiveActivity()
        FocusControl()
    }
}
