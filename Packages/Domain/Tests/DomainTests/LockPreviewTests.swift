import Foundation
import Testing
@testable import Domain

@Suite("片づけたあとの見通し")
struct LockPreviewTests {
    let engine = LockEngine(calendar: tokyo)
    /// 10/9(金)14:00。
    let now = date(9, 14)

    @Test("目標を終えると、次のロックは次の予定まで延びる")
    func resolvingGoalMovesNextLock() {
        let world = World.exact(
            goals: [
                .fixture(1, title: "院試", lockStart: .timeOfDay(minutes: 15 * 60)),
                .fixture(2, title: "TOEIC", lockStart: .timeOfDay(minutes: 21 * 60)),
            ]
        )
        // いまは 15:00 に院試でロックされる予定。
        #expect(engine.status(world: world, now: now).phase == .free(nextLockAt: date(9, 15)))

        let preview = engine.preview(resolving: .goal(uuid(1)), world: world, now: now)
        #expect(preview.unlocks)
        #expect(preview.nextLockAt == date(9, 21))
        #expect(!preview.isFreeForToday)
    }

    @Test("最後の1つを終えると、今日は自由になる")
    func resolvingLastReasonFreesToday() {
        let world = World.exact(goals: [.fixture()])
        let preview = engine.preview(resolving: .goal(uuid(1)), world: world, now: now)
        #expect(preview.unlocks)
        #expect(preview.isFreeForToday)
        #expect(preview.nextLockAt == date(10, 4))
    }

    @Test("ほかに理由が残っていれば、ロックは外れない")
    func otherReasonsRemain() {
        let world = World.exact(goals: [.fixture()], tasks: [.fixture()])
        let preview = engine.preview(resolving: .goal(uuid(1)), world: world, now: date(9, 22))
        #expect(!preview.unlocks)
    }

    @Test("タスクを終えた場合も計算できる")
    func resolvingTask() {
        let world = World.exact(tasks: [.fixture()])
        let preview = engine.preview(resolving: .task(uuid(100)), world: world, now: date(9, 22))
        #expect(preview.unlocks)
        #expect(preview.nextLockAt == nil)
        #expect(preview.isFreeForToday)
    }

    @Test("途中まで進めた目標は、残りだけを足して計算する")
    func partialProgress() {
        let world = World.exact(
            goals: [.fixture(dailyMinutes: 30)],
            sessions: [.fixture(startedAt: date(9, 9), minutes: 20)]
        )
        #expect(engine.status(world: world, now: now).isLocked)
        #expect(engine.preview(resolving: .goal(uuid(1)), world: world, now: now).unlocks)
    }

    @Test("計測中の目標でも、終えたあとの見通しを正しく出す")
    func duringActiveFocus() {
        let world = World.exact(
            goals: [.fixture(dailyMinutes: 30)],
            activeFocus: ActiveFocus(goalID: uuid(1), startedAt: date(9, 13, 50))
        )
        let preview = engine.preview(resolving: .goal(uuid(1)), world: world, now: now)
        #expect(preview.unlocks)
        #expect(preview.isFreeForToday)
    }
}
