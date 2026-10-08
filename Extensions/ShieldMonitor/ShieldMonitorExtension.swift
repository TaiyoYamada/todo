// 予約した時刻に OS から起こされ、ロックを掛け直す拡張機能。
//
// 注意: 動作は未検証。実機と Family Controls の権限(有料の開発者登録)が必要。

import DeviceActivity
import Foundation
import SharedCore

final class ShieldMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        refresh()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        refresh()
    }

    /// 写しを読み直して、いまロックすべきかを判定する。
    /// 起こされた理由(どの予約か)は見ない。どの予約で起きても、やることは同じ。
    private func refresh() {
        #if !targetEnvironment(simulator)
            ShieldApplier.refresh()
        #endif
    }
}
