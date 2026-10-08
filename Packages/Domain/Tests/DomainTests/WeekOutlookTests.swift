import Foundation
import Testing

@testable import Domain

@Suite("週間のロック予報")
struct WeekOutlookTests {
    let engine = LockEngine(calendar: tokyo)
    /// 10/9(金)14:00。
    let now = date(9, 14)

    @Test("今日から7日ぶんを、日付順に返す")
    func sevenDays() {
        let outlook = engine.weekOutlook(world: World(), now: now)
        #expect(outlook.map(\.dayStart) == (9...15).map { date($0, 4) })
        #expect(outlook.allSatisfy { $0.severity == .clear })
    }

    @Test("目標は、やる曜日にだけ入る")
    func goalsFollowWeekdays() {
        let world = World.exact(goals: [.fixture(weekdays: [.monday, .wednesday])])
        let outlook = engine.weekOutlook(world: world, now: now)
        // 10/9(金)から数えて、月曜は 10/12、水曜は 10/14。
        #expect(outlook.map(\.severity) == [.clear, .clear, .clear, .routine, .clear, .routine, .clear])
        #expect(outlook[3].firstLockAt == date(12, 4))
    }

    @Test("タスクは、着手リミットの日に入る")
    func tasksOnStartLimitDay() {
        let world = World.exact(tasks: [
            // 締切 10/11 13:00、所要 3 時間。着手リミットは 10/11 10:00。
            .fixture(100, title: "発表資料", dueAt: date(11, 13), estimateMinutes: 180),
            .fixture(101, title: "レポート", dueAt: date(11, 23, 59), estimateMinutes: 120),
            .fixture(102, title: "課題", dueAt: date(13, 18), estimateMinutes: 60),
        ])
        let outlook = engine.weekOutlook(world: world, now: now)
        #expect(outlook[2].entries.map(\.title) == ["発表資料", "レポート"])
        #expect(outlook[2].severity == .heavy)
        #expect(outlook[4].severity == .deadline)
        #expect(outlook[4].firstLockAt == date(13, 17))
    }

    @Test("今日のぶんは、済んだものも含む")
    func todayIncludesCleared() {
        let world = World.exact(
            goals: [.fixture()],
            sessions: [.fixture(startedAt: date(9, 9), minutes: 30)]
        )
        let today = engine.weekOutlook(world: world, now: now)[0]
        #expect(today.entries.map(\.state) == [.cleared])
        // 片づいているので、荒れ具合には数えない。
        #expect(today.severity == .clear)
        #expect(today.firstLockAt == nil)
    }

    @Test("深夜1時のリミットは、前の日のぶんとして数える")
    func afterMidnightBelongsToPreviousDay() {
        // 締切 10/11 02:00、所要 1 時間。着手リミットは 10/11 01:00 で、10/10 の1日に含まれる。
        let world = World.exact(tasks: [.fixture(dueAt: date(11, 2), estimateMinutes: 60)])
        let outlook = engine.weekOutlook(world: world, now: now)
        #expect(outlook[1].pendingTaskCount == 1)
        #expect(outlook[2].pendingTaskCount == 0)
    }
}
