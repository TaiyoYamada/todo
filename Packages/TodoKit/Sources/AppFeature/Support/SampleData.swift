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
        /// 目標の今日の分は終えたが、タスクの着手リミットを過ぎて、ロックされている。
        case taskLocked
        /// ロックはまだだが、今日のうちに次のロックが来る。
        case countdown
        /// 今日の分をすべて終えて、自由。
        case free
        /// 何も登録していない。初回設定から始まる。
        case fresh
    }

    static func world(_ scenario: Scenario, now: Date = .now, calendar: Calendar = .current) -> World {
        guard scenario != .fresh else { return World() }

        let days = Days(now: now, calendar: calendar)
        let exam = Goal(
            id: id(1),
            title: text("大学院入試", "Grad school exam"),
            symbol: "graduationcap.fill",
            tint: .indigo,
            dailyMinutes: 45,
            createdAt: days.at(-20, hour: 12)
        )
        let english = Goal(
            id: id(2),
            title: "TOEIC",
            symbol: "globe",
            tint: .teal,
            dailyMinutes: 20,
            weekdays: Weekday.everyDay,
            // 2 時間 14 分後にロックが来る。
            lockStart: .timeOfDay(minutes: days.minutesOfDay(now.addingTimeInterval(2 * 3600 + 14 * 60))),
            createdAt: days.at(-12, hour: 12)
        )

        var sessions = history(exam: exam, english: english, days: days)
        var tasks = tasks(now: now, days: days)
        // 今日の分を終えた記録。大学院入試は 3 時間前、TOEIC は 2 時間前に終えたことにする。
        let examToday = FocusSession(
            id: id(300),
            goalID: exam.id,
            startedAt: now.addingTimeInterval(-3 * 3600),
            seconds: 45 * 60
        )
        let englishToday = FocusSession(
            id: id(301),
            goalID: english.id,
            startedAt: now.addingTimeInterval(-2 * 3600),
            seconds: 20 * 60
        )

        switch scenario {
        case .locked, .fresh:
            break
        case .taskLocked:
            sessions.append(examToday)
            // 締切まで 1 時間。所要 90 分なので、着手リミットはもう過ぎている。
            tasks[0].dueAt = now.addingTimeInterval(3600)
        case .countdown:
            sessions.append(examToday)
        case .free:
            sessions.append(examToday)
            sessions.append(englishToday)
            tasks[0].completedAt = now.addingTimeInterval(-3600)
            tasks[0].actualMinutes = 120
        }

        return World(
            goals: [exam, english],
            tasks: tasks,
            sessions: sessions,
            passUses: [PassUse(id: id(400), usedAt: days.at(-2, hour: 22), minutes: 15)],
            preferences: Preferences(dayStartHour: days.dayStartHour, hasCompletedOnboarding: true)
        )
    }

    // MARK: - 部品

    /// 見本データの中の日時を、「今日から何日前の何時」で作る。
    private struct Days {
        let calendar: Calendar
        let dayStartHour: Int
        private let clock: DayClock
        private let today: Date

        init(now: Date, calendar: Calendar) {
            self.calendar = calendar
            // 1日の開始を「いまの 10 時間前」に合わせる。何時に起動しても、同じ場面を再現できるようにするため。
            // (本来の設定の範囲は外れるが、見本データに限って許す。)
            dayStartHour = calendar.component(.hour, from: now.addingTimeInterval(-10 * 3600))
            clock = DayClock(calendar: calendar, dayStartHour: dayStartHour)
            today = clock.dayStart(containing: now)
        }

        func at(_ offset: Int, hour: Int, minute: Int = 0) -> Date {
            let start = clock.offset(today, days: offset)
            return clock.time(minutesFromMidnight: hour * 60 + minute, inDayStarting: start)
        }

        func minutesOfDay(_ date: Date) -> Int {
            let parts = calendar.dateComponents([.hour, .minute], from: date)
            return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }
    }

    private static func text(_ japanese: String, _ english: String) -> String {
        Locale.current.language.languageCode?.identifier == "ja" ? japanese : english
    }

    /// 毎回同じ ID にする。起動のたびに変わると、画面の状態を比べにくい。
    private static func id(_ value: Int) -> UUID {
        let text = "5A3F1E00-0000-4000-8000-" + String(format: "%012d", value)
        guard let id = UUID(uuidString: text) else {
            preconditionFailure("見本データの ID を作れない: \(text)")
        }
        return id
    }

    /// 過去 13 日ぶんの記録。日によって量を変えて、グラフに起伏を出す。
    private static func history(exam: Goal, english: Goal, days: Days) -> [FocusSession] {
        var sessions: [FocusSession] = []
        let examMinutes = [45, 45, 30, 0, 45, 60, 45, 20, 45, 45, 0, 45, 50]
        let englishMinutes = [20, 0, 20, 20, 25, 20, 0, 20, 20, 30, 20, 20, 20]
        for (index, minutes) in examMinutes.enumerated() where minutes > 0 {
            sessions.append(
                FocusSession(
                    id: id(100 + index),
                    goalID: exam.id,
                    startedAt: days.at(index - 13, hour: 9),
                    seconds: minutes * 60
                )
            )
        }
        for (index, minutes) in englishMinutes.enumerated() where index >= 1 && minutes > 0 {
            sessions.append(
                FocusSession(
                    id: id(200 + index),
                    goalID: english.id,
                    startedAt: days.at(index - 13, hour: 19),
                    seconds: minutes * 60
                )
            )
        }
        return sessions
    }

    /// 未完了が 2 件(今日のうちに着手リミットが来るものと、明後日のもの)と、完了済みが 3 件。
    private static func tasks(now: Date, days: Days) -> [TaskItem] {
        [
            TaskItem(
                id: id(10),
                title: text("統計学のレポート", "Statistics report"),
                dueAt: now.addingTimeInterval(9 * 3600),
                estimateMinutes: 90,
                createdAt: days.at(-3, hour: 12)
            ),
            TaskItem(
                id: id(11),
                title: text("ゼミの発表資料", "Seminar slides"),
                dueAt: now.addingTimeInterval(52 * 3600),
                estimateMinutes: 180,
                createdAt: days.at(-2, hour: 12)
            ),
            // 完了済み。見積もりより長くかかった実績として、倍率の学習に使われる。
            TaskItem(
                id: id(12),
                title: text("線形代数の課題", "Linear algebra homework"),
                dueAt: days.at(-1, hour: 17),
                estimateMinutes: 60,
                actualMinutes: 90,
                completedAt: days.at(-1, hour: 11),
                createdAt: days.at(-5, hour: 12)
            ),
            TaskItem(
                id: id(13),
                title: text("実験ノートの提出", "Lab notebook"),
                dueAt: days.at(-4, hour: 23, minute: 59),
                estimateMinutes: 30,
                actualMinutes: 60,
                completedAt: days.at(-4, hour: 23),
                createdAt: days.at(-8, hour: 12)
            ),
            TaskItem(
                id: id(14),
                title: text("奨学金の書類", "Scholarship forms"),
                dueAt: days.at(-6, hour: 17),
                estimateMinutes: 40,
                actualMinutes: 60,
                completedAt: days.at(-7, hour: 20),
                createdAt: days.at(-10, hour: 12)
            ),
        ]
    }
}
