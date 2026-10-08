import Domain
import Foundation
import Testing
@testable import AppFeature

@Suite("今日の画面のいちばん上の表示")
struct HeroTests {
    let engine = LockEngine(calendar: tokyo)
    /// 10/9(金)14:00。この日は 10/9 4:00 から 10/10 4:00 まで。
    let now = date(9, 14)

    private func hero(_ world: World) -> Hero {
        Hero(status: engine.status(world: world, now: now), world: world)
    }

    private var goalReason: LockReason {
        LockReason(source: .goal(uuid(1)), title: "院試", startsAt: date(9, 4), remainingSeconds: 30 * 60)
    }

    // MARK: 何もないとき

    @Test("目標もタスクもなければ、最初の案内を出す")
    func emptyWorld() {
        #expect(hero(World()) == .empty)
    }

    @Test("しまった目標と片づけたタスクしかなければ、最初の案内を出す")
    func onlyArchivedAndClosed() {
        var archived = Goal.fixture()
        archived.isArchived = true
        let world = World.exact(
            goals: [archived],
            tasks: [
                .fixture(100, completedAt: date(9, 10)),
                .fixture(101, withdrawnAt: date(9, 11)),
            ]
        )
        #expect(hero(world) == .empty)
    }

    // MARK: ロック中

    @Test("ロック中は、いちばん先に始まった理由を出す")
    func lockedByGoal() {
        #expect(hero(.exact(goals: [.fixture()])) == .locked(primary: goalReason, others: 0))
    }

    @Test("ロックの理由がほかにもあれば、その件数を添える")
    func lockedWithOthers() {
        let world = World.exact(
            goals: [.fixture()],
            tasks: [
                // 着手リミットは 13:00 と 13:30。どちらも過ぎている。
                .fixture(100, title: "レポート", dueAt: date(9, 15), estimateMinutes: 120),
                .fixture(101, title: "発表資料", dueAt: date(9, 15), estimateMinutes: 90),
            ]
        )
        #expect(hero(world) == .locked(primary: goalReason, others: 2))
    }

    @Test("タスクだけが理由のときは、そのタスクを出す")
    func lockedByTask() {
        let world = World.exact(tasks: [.fixture(dueAt: date(9, 15), estimateMinutes: 120)])
        let reason = LockReason(source: .task(uuid(100)), title: "レポート", startsAt: date(9, 13), dueAt: date(9, 15))
        #expect(hero(world) == .locked(primary: reason, others: 0))
    }

    // MARK: パス

    @Test("パスを使っている間は、切れる時刻と、片づけるものを出す")
    func onPass() {
        let world = World.exact(
            goals: [.fixture()],
            passUses: [PassUse(id: uuid(300), usedAt: date(9, 13, 50), minutes: 15)]
        )
        #expect(hero(world) == .onPass(until: date(9, 14, 5), primary: goalReason))
    }

    @Test("パスが切れたら、ロック中に戻る")
    func passExpired() {
        let world = World.exact(
            goals: [.fixture()],
            passUses: [PassUse(id: uuid(300), usedAt: date(9, 13, 45), minutes: 15)]
        )
        #expect(hero(world) == .locked(primary: goalReason, others: 0))
    }

    // MARK: 余裕

    @Test("今日のうちにタスクの着手リミットが来るなら、そこまでの余裕を出す")
    func countdownToTask() {
        let world = World.exact(tasks: [.fixture(dueAt: date(9, 23, 59), estimateMinutes: 120)])
        let reason = LockReason(
            source: .task(uuid(100)),
            title: "レポート",
            startsAt: date(9, 21, 59),
            dueAt: date(9, 23, 59)
        )
        #expect(hero(world) == .countdown(until: date(9, 21, 59), reason: reason))
    }

    @Test("時刻を指定した目標は、その時刻までの余裕を出す")
    func countdownToGoal() {
        let world = World.exact(goals: [.fixture(lockStart: .timeOfDay(minutes: 20 * 60))])
        let reason = LockReason(source: .goal(uuid(1)), title: "院試", startsAt: date(9, 20), remainingSeconds: 30 * 60)
        #expect(hero(world) == .countdown(until: date(9, 20), reason: reason))
    }

    @Test("次のロックが複数あれば、いちばん近いものを出す")
    func countdownPicksEarliest() {
        let world = World.exact(
            goals: [.fixture(lockStart: .timeOfDay(minutes: 20 * 60))],
            tasks: [.fixture(dueAt: date(9, 18), estimateMinutes: 60)]
        )
        let reason = LockReason(source: .task(uuid(100)), title: "レポート", startsAt: date(9, 17), dueAt: date(9, 18))
        #expect(hero(world) == .countdown(until: date(9, 17), reason: reason))
    }

    // MARK: 1日の終わりの境目

    @Test("次のロックが1日の終わりの直前なら、まだ今日のロックとして数える")
    func lockJustBeforeDayEndIsCountdown() {
        // 着手リミットは翌 3:59。この日は翌 4:00 まで。
        let world = World.exact(tasks: [.fixture(dueAt: date(10, 5, 59), estimateMinutes: 120)])
        let reason = LockReason(
            source: .task(uuid(100)),
            title: "レポート",
            startsAt: date(10, 3, 59),
            dueAt: date(10, 5, 59)
        )
        #expect(hero(world) == .countdown(until: date(10, 3, 59), reason: reason))
    }

    @Test("次のロックが1日の終わりちょうどなら、今日は自由")
    func lockAtDayEndIsFreeToday() {
        let world = World.exact(tasks: [.fixture(dueAt: date(10, 6), estimateMinutes: 120)])
        #expect(hero(world) == .freeToday(nextLockAt: date(10, 4)))
    }

    // MARK: 今日は自由

    @Test("今日の分を終えたら今日は自由で、次のロックは翌朝")
    func freeAfterFinishingGoal() {
        let world = World.exact(
            goals: [.fixture()],
            sessions: [.fixture(startedAt: date(9, 9), minutes: 30)]
        )
        #expect(hero(world) == .freeToday(nextLockAt: date(10, 4)))
    }

    @Test("今日作った目標は今日はロックせず、次のロックは翌朝")
    func goalCreatedTodayIsFreeToday() {
        let world = World.exact(goals: [.fixture(createdAt: date(9, 10))])
        #expect(hero(world) == .freeToday(nextLockAt: date(10, 4)))
    }

    @Test("何日も先のタスクしかなければ今日は自由で、その着手リミットを次のロックとして出す")
    func farTaskIsFreeToday() {
        let world = World.exact(tasks: [.fixture(dueAt: date(20, 18), estimateMinutes: 60)])
        #expect(hero(world) == .freeToday(nextLockAt: date(20, 17)))
    }

    @Test("ロックの予定がまったくなければ、次のロックは出さない")
    func noUpcomingLock() {
        // 量が 0 の目標は、ロックの理由にならない。
        let world = World.exact(goals: [.fixture(dailyMinutes: 0)])
        #expect(hero(world) == .freeToday(nextLockAt: nil))
    }

    // MARK: 食い違った入力

    @Test("ロック中なのに理由が空という食い違った状態では、自由として扱う")
    func lockedWithoutReasonsFallsBackToFree() {
        let world = World.exact(goals: [.fixture()])
        var status = engine.status(world: world, now: now)
        status.activeReasons = []
        #expect(Hero(status: status, world: world) == .freeToday(nextLockAt: nil))

        status.phase = .onPass(until: date(9, 14, 5))
        #expect(Hero(status: status, world: world) == .freeToday(nextLockAt: nil))
    }
}
