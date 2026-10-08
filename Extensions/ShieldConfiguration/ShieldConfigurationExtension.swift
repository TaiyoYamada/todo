// ロックされたアプリを開いたときに出る画面の、文言と色を決める拡張機能。
//
// 注意: 動作は未検証。実機と Family Controls の権限(有料の開発者登録)が必要。

import Domain
import ManagedSettings
import ManagedSettingsUI
import SharedCore
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding _: Application) -> ShieldConfiguration {
        make()
    }

    override func configuration(shielding _: Application, in _: ActivityCategory) -> ShieldConfiguration {
        make()
    }

    override func configuration(shielding _: WebDomain) -> ShieldConfiguration {
        make()
    }

    override func configuration(shielding _: WebDomain, in _: ActivityCategory) -> ShieldConfiguration {
        make()
    }

    private func make() -> ShieldConfiguration {
        let accent = UIColor(red: 1.00, green: 0.48, blue: 0.52, alpha: 1)
        let reason = currentReason()
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0.16, green: 0.03, blue: 0.09, alpha: 0.92),
            icon: UIImage(systemName: "lock.fill"),
            title: ShieldConfiguration.Label(
                text: reason?.title ?? String(localized: "shield.title.fallback"),
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(text: subtitle(for: reason), color: UIColor.white.withAlphaComponent(0.75)),
            primaryButtonLabel: ShieldConfiguration.Label(text: String(localized: "shield.button"), color: .black),
            primaryButtonBackgroundColor: accent
        )
    }

    /// いちばん先に片づけるもの。写しが読めなければ nil。
    private func currentReason() -> LockReason? {
        guard let snapshot = SnapshotStore.load() else { return nil }
        return LockEngine(calendar: .current).status(world: snapshot.world, now: Date()).activeReasons.first
    }

    private func subtitle(for reason: LockReason?) -> String {
        guard let reason else { return String(localized: "shield.subtitle.fallback") }
        if let remaining = reason.remainingSeconds {
            let minutes = max(1, Int((Double(remaining) / 60).rounded(.up)))
            return String(localized: "shield.subtitle.goal \(minutes)")
        }
        return String(localized: "shield.subtitle.task")
    }
}
