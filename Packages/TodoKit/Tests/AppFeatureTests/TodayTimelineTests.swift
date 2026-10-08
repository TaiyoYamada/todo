import Domain
import Foundation
import Testing
@testable import AppFeature

@Suite("今日の行の並べ方")
struct TodayTimelineTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)) ?? .distantPast
    }

    private func uuid(_ value: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-" + String(format: "%012d", value)) ?? UUID()
    }

    private func items(_ world: World, now: Date) -> [TimelineItem] {
        TodayTimeline.items(status: LockEngine(calendar: calendar).status(world: world, now: now), world: world)
    }

    @Test("片づいていないものを時刻順に上へ、片づいたものを下へ並べる")
    func order() {
        let world = World(
            goals: [
                Goal(id: uuid(1), title: "院試", dailyMinutes: 30, createdAt: date(8, 12)),
                Goal(
                    id: uuid(2),
                    title: "TOEIC",
                    dailyMinutes: 20,
                    lockStart: .timeOfDay(minutes: 18 * 60),
                    createdAt: date(8, 12)
                ),
            ],
            tasks: [
                TaskItem(
                    id: uuid(10),
                    title: "レポート",
                    dueAt: date(9, 23, 59),
                    estimateMinutes: 120,
                    createdAt: date(8, 12)
                ),
                // 明後日が締切のものは、今日の行に出ない。
                TaskItem(id: uuid(11), title: "発表資料", dueAt: date(11, 18), estimateMinutes: 60, createdAt: date(8, 12)),
            ],
            sessions: [FocusSession(id: uuid(20), goalID: uuid(1), startedAt: date(9, 9), seconds: 30 * 60)],
            preferences: Preferences(buffer: .none)
        )
        let result = items(world, now: date(9, 14))
        #expect(result.map(\.title) == ["TOEIC", "レポート", "院試"])
        #expect(result.map(\.state) == [.upcoming, .upcoming, .cleared])
        #expect(result.map(\.at) == [date(9, 18), date(9, 21, 59), date(9, 4)])
    }

    @Test("いまロックの理由になっているものは active になる")
    func active() {
        let world = World(
            goals: [Goal(id: uuid(1), title: "院試", dailyMinutes: 30, createdAt: date(8, 12))],
            tasks: [
                TaskItem(id: uuid(10), title: "レポート", dueAt: date(9, 15), estimateMinutes: 120, createdAt: date(8, 12)),
            ],
            preferences: Preferences(buffer: .none)
        )
        let result = items(world, now: date(9, 14))
        #expect(result.map(\.title) == ["院試", "レポート"])
        #expect(result.map(\.state) == [.active, .active])
    }

    @Test("作った当日の目標は、時刻なしで最後に並ぶ")
    func optionalGoal() {
        let world = World(
            goals: [
                Goal(id: uuid(1), title: "新しい目標", dailyMinutes: 30, createdAt: date(9, 10)),
                Goal(
                    id: uuid(2),
                    title: "TOEIC",
                    dailyMinutes: 20,
                    lockStart: .timeOfDay(minutes: 18 * 60),
                    createdAt: date(8, 12)
                ),
            ]
        )
        let result = items(world, now: date(9, 14))
        #expect(result.map(\.title) == ["TOEIC", "新しい目標"])
        #expect(result.last?.state == .optional)
        #expect(result.last?.at == nil)
    }

    @Test("今日片づけたタスクは、済んだ行として残る")
    func clearedTask() {
        let world = World(
            tasks: [
                TaskItem(
                    id: uuid(10),
                    title: "提出済み",
                    dueAt: date(9, 12),
                    estimateMinutes: 60,
                    completedAt: date(9, 10),
                    createdAt: date(8, 12)
                ),
            ],
            preferences: Preferences(buffer: .none)
        )
        let result = items(world, now: date(9, 14))
        #expect(result.map(\.state) == [.cleared])
    }
}
