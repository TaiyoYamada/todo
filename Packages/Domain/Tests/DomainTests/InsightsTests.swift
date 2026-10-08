import Foundation
import Testing
@testable import Domain

@Suite("振り返りの集計")
struct InsightsTests {
    let calculator = InsightsCalculator(calendar: tokyo, dayCount: 3)
    /// 10/9(金)14:00。
    let now = date(9, 14)

    @Test("日ごとの合計を、古い日から今日の順に並べる")
    func days() {
        let world = World(
            goals: [.fixture(1, title: "院試"), .fixture(2, title: "TOEIC")],
            sessions: [
                .fixture(200, goal: 1, startedAt: date(7, 10), minutes: 20),
                .fixture(201, goal: 2, startedAt: date(9, 9), minutes: 15),
                .fixture(202, goal: 1, startedAt: date(9, 10), minutes: 30),
                // 10/9 の深夜2時は、10/8 に数える。
                .fixture(203, goal: 1, startedAt: date(9, 2), minutes: 10),
            ]
        )
        let insights = calculator.insights(world: world, now: now)
        #expect(insights.days.map(\.dayStart) == [date(7, 4), date(8, 4), date(9, 4)])
        #expect(insights.days.map(\.totalSeconds) == [20 * 60, 10 * 60, 45 * 60])
        // 積み重ねの順は、目標の並び順。
        #expect(insights.days.last?.segments.map(\.goalID) == [uuid(1), uuid(2)])
        #expect(insights.hasAnyFocus)
    }

    @Test("今週と先週の合計")
    func weeks() {
        let world = World(
            goals: [.fixture()],
            sessions: [
                .fixture(200, startedAt: date(2, 10), minutes: 60),
                .fixture(201, startedAt: date(5, 10), minutes: 30),
                .fixture(202, startedAt: date(9, 10), minutes: 15),
            ]
        )
        let insights = calculator.insights(world: world, now: now)
        #expect(insights.thisWeekSeconds == 45 * 60)
        #expect(insights.lastWeekSeconds == 60 * 60)
    }

    @Test("タスクは、着手リミットの前後と取り下げで数える")
    func tasks() {
        let world = World.exact(tasks: [
            // 着手リミット 21:59 より前に完了。
            .fixture(100, completedAt: date(9, 12)),
            // 着手リミットを過ぎてから完了。
            .fixture(101, completedAt: date(9, 23)),
            .fixture(102, withdrawnAt: date(9, 22)),
            .fixture(103),
        ])
        let insights = calculator.insights(world: world, now: date(10, 14))
        #expect(insights.tasksBeforeLimit == 1)
        #expect(insights.tasksAfterLimit == 1)
        #expect(insights.tasksWithdrawn == 1)
    }

    @Test("記録がなければ、空として扱う")
    func empty() {
        let insights = calculator.insights(world: World(), now: now)
        #expect(!insights.hasAnyFocus)
        #expect(insights.days.count == 3)
    }
}
