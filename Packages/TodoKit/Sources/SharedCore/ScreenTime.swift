// スクリーンタイム API を直接使う部分。
//
// 注意: このファイルの動作は未検証。実機と、Family Controls の権限(有料の開発者登録)が必要で、
// シミュレータでは確かめられない。コンパイルが通ることだけを確認している。

#if canImport(FamilyControls) && !targetEnvironment(simulator)
    import DeviceActivity
    import Domain
    import FamilyControls
    import Foundation
    import ManagedSettings

    /// ロックの対象として利用者が選んだアプリ、カテゴリ、Web サイト。
    public enum SelectionStore {
        private static let key = "shieldSelection"

        public static func load() -> FamilyActivitySelection {
            guard
                let data = AppGroup.defaults?.data(forKey: key),
                let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            else { return FamilyActivitySelection() }
            return selection
        }

        public static func save(_ selection: FamilyActivitySelection) {
            guard let data = try? JSONEncoder().encode(selection) else { return }
            AppGroup.defaults?.set(data, forKey: key)
        }

        public static var count: Int {
            let selection = load()
            return selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
        }
    }

    /// 写しを読んで、いまロックを掛けるべきかを判定し、そのとおりにする。
    ///
    /// アプリ本体からも、予約した時刻に起こされた拡張機能からも呼ぶ。どちらから呼んでも同じ結果になる。
    public enum ShieldApplier {
        /// 設定の置き場。呼ぶたびに作るが、同じ名前なら同じ設定を指す。
        private static var store: ManagedSettingsStore {
            ManagedSettingsStore(named: ManagedSettingsStore.Name("lock"))
        }

        public static func refresh(now: Date = Date()) {
            guard let snapshot = SnapshotStore.load() else { return }
            let status = LockEngine(calendar: .current).status(world: snapshot.world, now: now)
            apply(isLocked: status.isLocked)
        }

        public static func apply(isLocked: Bool) {
            guard isLocked else {
                store.clearAllSettings()
                return
            }
            let selection = SelectionStore.load()
            store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
            store.shield.applicationCategories =
                selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
            store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        }
    }

    /// アプリを閉じていても、ロックが始まる時刻に拡張機能を起こしてもらうための予約。
    public enum MonitorScheduler {
        /// 予約の区間の長さ。OS が受け付ける最短が 15 分。
        private static let intervalMinutes = 15
        /// 毎日くり返す予約の上限。OS の上限 20 から、1回きりの予約(`ShieldPlan.wakeTimeLimit`)を引いた数。
        private static let dailyLimit = 20 - ShieldPlan.wakeTimeLimit

        public static func reschedule(plan: ShieldPlan, world: World, now: Date, calendar: Calendar = .current) {
            let center = DeviceActivityCenter()
            center.stopMonitoring()

            // 1. 1日の区切りと、目標のロックが始まる時刻。毎日くり返す。
            // 区切りの時刻は、目標がなくても必ず入れる。前の日のロックを、日付が変わった時点で外すため。
            var dailyMinutes: Set<Int> = [world.preferences.dayStartHour * 60]
            for goal in world.activeGoals where goal.dailyMinutes > 0 {
                switch goal.lockStart {
                case .dayStart:
                    dailyMinutes.insert(world.preferences.dayStartHour * 60)
                case let .timeOfDay(minutes):
                    dailyMinutes.insert(minutes)
                }
            }
            // 予約できる数には OS の上限(20)がある。1回きりの予約のぶんを残して、毎日のぶんはこの数までにする。
            for minutes in dailyMinutes.sorted().prefix(Self.dailyLimit) {
                let end = (minutes + intervalMinutes) % (24 * 60)
                let schedule = DeviceActivitySchedule(
                    intervalStart: DateComponents(hour: minutes / 60, minute: minutes % 60),
                    intervalEnd: DateComponents(hour: end / 60, minute: end % 60),
                    repeats: true
                )
                try? center.startMonitoring(DeviceActivityName("daily-\(minutes)"), during: schedule)
            }

            // 2. タスクの着手リミットと、パスが切れる時刻。1 回きり。
            let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
            for (index, date) in plan.wakeTimes.enumerated() where date > now {
                let end = date.addingTimeInterval(Double(intervalMinutes) * 60)
                let schedule = DeviceActivitySchedule(
                    intervalStart: calendar.dateComponents(parts, from: date),
                    intervalEnd: calendar.dateComponents(parts, from: end),
                    repeats: false
                )
                try? center.startMonitoring(DeviceActivityName("once-\(index)"), during: schedule)
            }
        }
    }
#endif
