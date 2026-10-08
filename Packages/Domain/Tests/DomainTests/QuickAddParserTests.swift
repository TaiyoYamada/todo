import Foundation
import Testing

@testable import Domain

@Suite("1行からのタスクの読み取り")
struct QuickAddParserTests {
    let parser = QuickAddParser(calendar: tokyo)
    /// 10/9(金)14:00。
    let now = date(9, 14)

    private func parse(_ text: String) -> QuickAdd {
        parser.parse(text, now: now)
    }

    @Test("日本語: 曜日と所要時間")
    func japaneseWeekdayAndDuration() {
        // 今日が金曜なので、「金曜」は今日。
        #expect(parse("金曜までにレポート 2時間") == QuickAdd(title: "レポート", dueAt: date(9, 23, 59), estimateMinutes: 120))
        #expect(parse("月曜日 発表資料 3時間") == QuickAdd(title: "発表資料", dueAt: date(12, 23, 59), estimateMinutes: 180))
        #expect(parse("来週の金曜までに論文の下書き") == QuickAdd(title: "論文の下書き", dueAt: date(16, 23, 59)))
    }

    @Test("日本語: 明日、明後日、時刻")
    func japaneseRelativeDays() {
        #expect(parse("レポートを明日までに 90分") == QuickAdd(title: "レポート", dueAt: date(10, 23, 59), estimateMinutes: 90))
        #expect(parse("明日18時 ゼミの準備 1時間半") == QuickAdd(title: "ゼミの準備", dueAt: date(10, 18), estimateMinutes: 90))
        #expect(parse("あさって午後6時半に課題提出") == QuickAdd(title: "課題提出", dueAt: date(11, 18, 30)))
        #expect(parse("今日 23:59 統計学のレポート 1時間30分") == QuickAdd(title: "統計学のレポート", dueAt: date(9, 23, 59), estimateMinutes: 90))
    }

    @Test("日付の書き方")
    func explicitDates() {
        #expect(parse("10/12 17:00 奨学金の書類 40分") == QuickAdd(title: "奨学金の書類", dueAt: date(12, 17), estimateMinutes: 40))
        #expect(parse("10月20日 レポート") == QuickAdd(title: "レポート", dueAt: date(20, 23, 59)))
        // もう過ぎた日付は、来年として読む。
        #expect(parse("3/1 確定申告").dueAt == date(1, 23, 59, month: 3, year: 2027))
    }

    @Test("時刻だけなら、今日。過ぎていれば明日")
    func timeOnly() {
        #expect(parse("18時 買い物").dueAt == date(9, 18))
        #expect(parse("9時 朝会の準備").dueAt == date(10, 9))
    }

    @Test("英語")
    func english() {
        #expect(parse("Report by Friday 2h") == QuickAdd(title: "Report", dueAt: date(9, 23, 59), estimateMinutes: 120))
        #expect(parse("Seminar slides tomorrow 6pm 1h30m") == QuickAdd(title: "Seminar slides", dueAt: date(10, 18), estimateMinutes: 90))
        #expect(parse("next Mon lab notebook 45 min") == QuickAdd(title: "lab notebook", dueAt: date(19, 23, 59), estimateMinutes: 45))
        #expect(parse("Design review at 9:30am") == QuickAdd(title: "Design review", dueAt: date(10, 9, 30)))
    }

    @Test("全角の数字も読める")
    func fullWidthDigits() {
        #expect(parse("明日１８時 レポート ２時間") == QuickAdd(title: "レポート", dueAt: date(10, 18), estimateMinutes: 120))
    }

    @Test("読み取れるものがなければ、名前だけ")
    func plainTitle() {
        let result = parse("統計学のレポート")
        #expect(result == QuickAdd(title: "統計学のレポート"))
        #expect(!result.hasDetails)
    }

    @Test("単語の一部を、曜日や単位として読まない")
    func noFalsePositives() {
        #expect(parse("Sunny day monitor setup") == QuickAdd(title: "Sunny day monitor setup"))
        #expect(parse("5 hello world") == QuickAdd(title: "5 hello world"))
        #expect(parse("時間割の確認") == QuickAdd(title: "時間割の確認"))
    }

    @Test("「24時」は、その日の終わりとして読む")
    func midnight() {
        #expect(parse("明日24時 提出").dueAt == date(10, 23, 59))
    }
}
