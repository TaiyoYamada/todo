import Domain
import Foundation

/// 見本データ。プレビュー、開発中の動作確認、UI テスト、ストア用の画面撮影に使う。
///
/// 本番の保存データには一切触れない(メモリ上のデータベースに入れて使う)。
enum SampleData {
    /// どの状態を再現するか。
    enum Scenario: String, CaseIterable {
        /// 今日の分が残っていて、ロックされている。
        case locked
        /// ロックはまだだが、今日のうちに次のロックが来る。
        case countdown
        /// 今日の分をすべて終えて、自由。
        case free
        /// 何も登録していない。初回設定から始まる。
        case fresh
    }

    static func world(_ scenario: Scenario, now: Date = .now, calendar: Calendar = .current) -> World {
        guard scenario != .fresh else { return World() }

        let isJapanese = Locale.current.language.languageCode?.identifier == "ja"
        func text(_ ja: String, _ en: String) -> String { isJapanese ? ja : en }
        func id(_ value: Int) -> UUID {
            UUID(uuidString: "5A3F1E00-0000-4000-8000-" + String(format: "%012d", value)) ?? UUID()
        }

        // 1日の開始を「いまの 10 時間前」に合わせる。何時に起動しても、同じ場面を再現できるようにするため。
        // (本来の設定の範囲は外れるが、見本データに限って許す。)
        let dayStartHour = calendar.component(.hour, from: now.addingTimeInterval(-10 * 3600))
        let clock = DayClock(calendar: calendar, dayStartHour: dayStartHour)
        let today = clock.dayStart(containing: now)
        func minutesOfDay(_ date: Date) -> Int {
            let parts = calendar.dateComponents([.hour, .minute], from: date)
            return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }
        func day(_ offset: Int, hour: Int, minute: Int = 0) -> Date {
            let start = clock.offset(today, days: offset)
            return clock.time(minutesFromMidnight: hour * 60 + minute, inDayStarting: start)
        }

        let exam = Goal(
            id: id(1),
            title: text("大学院入試", "Grad school exam"),
            symbol: "graduationcap.fill",
            tint: .indigo,
            dailyMinutes: 45,
            createdAt: day(-20, hour: 12)
        )
        let english = Goal(
            id: id(2),
            title: "TOEIC",
            symbol: "globe",
            tint: .teal,
            dailyMinutes: 20,
            weekdays: Weekday.everyDay,
            // 2 時間 14 分後にロックが来る。
            lockStart: .timeOfDay(minutes: minutesOfDay(now.addingTimeInterval(2 * 3600 + 14 * 60))),
            createdAt: day(-12, hour: 12)
        )

        // 過去 13 日ぶんの記録。日によって量を変えて、グラフに起伏を出す。
        var sessions: [FocusSession] = []
        let examMinutes = [45, 45, 30, 0, 45, 60, 45, 20, 45, 45, 0, 45, 50]
        let englishMinutes = [20, 0, 20, 20, 25, 20, 0, 20, 20, 30, 20, 20, 20]
        for (index, minutes) in examMinutes.enumerated() where minutes > 0 {
            sessions.append(
                FocusSession(id: id(100 + index), goalID: exam.id, startedAt: day(index - 13, hour: 9), seconds: minutes * 60)
            )
        }
        for (index, minutes) in englishMinutes.enumerated() where index >= 1 && minutes > 0 {
            sessions.append(
                FocusSession(id: id(200 + index), goalID: english.id, startedAt: day(index - 13, hour: 19), seconds: minutes * 60)
            )
        }

        var tasks = [
            TaskItem(
                id: id(10),
                title: text("統計学のレポート", "Statistics report"),
                dueAt: now.addingTimeInterval(9 * 3600),
                estimateMinutes: 90,
                createdAt: day(-3, hour: 12)
            ),
            TaskItem(
                id: id(11),
                title: text("ゼミの発表資料", "Seminar slides"),
                dueAt: now.addingTimeInterval(52 * 3600),
                estimateMinutes: 180,
                createdAt: day(-2, hour: 12)
            ),
            // 完了済み。見積もりより長くかかった実績として、倍率の学習に使われる。
            TaskItem(
                id: id(12),
                title: text("線形代数の課題", "Linear algebra homework"),
                dueAt: day(-1, hour: 17),
                estimateMinutes: 60,
                actualMinutes: 90,
                completedAt: day(-1, hour: 11),
                createdAt: day(-5, hour: 12)
            ),
            TaskItem(
                id: id(13),
                title: text("実験ノートの提出", "Lab notebook"),
                dueAt: day(-4, hour: 23, minute: 59),
                estimateMinutes: 30,
                actualMinutes: 60,
                completedAt: day(-4, hour: 23),
                createdAt: day(-8, hour: 12)
            ),
            TaskItem(
                id: id(14),
                title: text("奨学金の書類", "Scholarship forms"),
                dueAt: day(-6, hour: 17),
                estimateMinutes: 40,
                actualMinutes: 60,
                completedAt: day(-7, hour: 20),
                createdAt: day(-10, hour: 12)
            ),
        ]

        switch scenario {
        case .locked, .fresh:
            break
        case .countdown:
            sessions.append(
                FocusSession(id: id(300), goalID: exam.id, startedAt: now.addingTimeInterval(-3 * 3600), seconds: 45 * 60)
            )
        case .free:
            sessions.append(
                FocusSession(id: id(300), goalID: exam.id, startedAt: now.addingTimeInterval(-3 * 3600), seconds: 45 * 60)
            )
            sessions.append(
                FocusSession(id: id(301), goalID: english.id, startedAt: now.addingTimeInterval(-2 * 3600), seconds: 20 * 60)
            )
            tasks[0].completedAt = now.addingTimeInterval(-3600)
            tasks[0].actualMinutes = 120
        }

        return World(
            goals: [exam, english],
            tasks: tasks,
            sessions: sessions,
            passUses: [PassUse(id: id(400), usedAt: day(-2, hour: 22), minutes: 15)],
            preferences: Preferences(dayStartHour: dayStartHour, hasCompletedOnboarding: true)
        )
    }
}
