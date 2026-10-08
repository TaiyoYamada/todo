import Foundation
import Testing
@testable import Domain

@Suite("ロックの判定")
struct LockEngineTests {
    let engine = LockEngine(calendar: tokyo)
    /// 10/9(金)14:00。
    let now = date(9, 14)

    // MARK: 何もないとき

    @Test("目標もタスクもなければ、ロックされない")
    func emptyWorldIsFree() {
        let status = engine.status(world: World(), now: now)
        #expect(status.phase == .free(nextLockAt: nil))
        #expect(status.slack == nil)
        #expect(status.isFreeForToday)
    }

    // MARK: 目標

    @Test("今日の分が終わっていなければ、朝からロックされる")
    func unfinishedGoalLocksFromDayStart() {
        let status = engine.status(world: World(goals: [.fixture()]), now: now)
        #expect(status.isLocked)
        #expect(status.activeReasons.map(\.source) == [.goal(uuid(1))])
        #expect(status.activeReasons.first?.remainingSeconds == 30 * 60)
        #expect(status.activeReasons.first?.startsAt == date(9, 4))
    }

    @Test("作った当日は、ロックしない")
    func goalDoesNotLockOnCreationDay() {
        let world = World(goals: [.fixture(createdAt: date(9, 10))])
        let status = engine.status(world: world, now: now)
        #expect(!status.isLocked)
        #expect(status.goals.count == 1)
        #expect(status.goals.first?.lockStartsAt == nil)
        // 翌朝からはロックの予定に入る。
        #expect(status.phase == .free(nextLockAt: date(10, 4)))
    }

    @Test("今日の分を終えると、ロックが外れる")
    func finishedGoalUnlocks() {
        let world = World(
            goals: [.fixture()],
            sessions: [
                .fixture(200, startedAt: date(9, 9), minutes: 10),
                .fixture(201, startedAt: date(9, 12), minutes: 20),
            ]
        )
        let status = engine.status(world: world, now: now)
        #expect(!status.isLocked)
        #expect(status.goals.first?.isComplete == true)
        #expect(status.isFreeForToday)
        #expect(status.phase == .free(nextLockAt: date(10, 4)))
    }

    @Test("前の日の記録は、今日の分に数えない")
    func yesterdaysSessionsDoNotCount() {
        let world = World(
            goals: [.fixture()],
            // 10/9 の深夜3時は、10/8 の1日に含まれる。
            sessions: [.fixture(startedAt: date(9, 3), minutes: 60)]
        )
        #expect(engine.status(world: world, now: now).isLocked)
    }

    @Test("計測中のぶんも数え、今日の分に達した時点で外れる")
    func activeFocusCountsTowardToday() {
        var world = World(
            goals: [.fixture()],
            sessions: [.fixture(startedAt: date(9, 9), minutes: 10)],
            activeFocus: ActiveFocus(goalID: uuid(1), startedAt: date(9, 13, 45))
        )
        let partial = engine.status(world: world, now: now)
        #expect(partial.isLocked)
        #expect(partial.goals.first?.doneSeconds == 25 * 60)

        world.activeFocus = ActiveFocus(goalID: uuid(1), startedAt: date(9, 13, 40))
        #expect(!engine.status(world: world, now: now).isLocked)
    }

    @Test("やる曜日でなければ、今日の目標に入らない")
    func restDay() {
        let world = World(goals: [.fixture(weekdays: [.monday, .wednesday])])
        let status = engine.status(world: world, now: now)
        #expect(status.goals.isEmpty)
        // 次のロックは月曜の朝。
        #expect(status.phase == .free(nextLockAt: date(12, 4)))
        #expect(status.isFreeForToday)
    }

    @Test("時刻を指定した目標は、その時刻まではロックしない")
    func timedGoal() {
        let world = World(goals: [.fixture(lockStart: .timeOfDay(minutes: 20 * 60))])
        let before = engine.status(world: world, now: now)
        #expect(before.phase == .free(nextLockAt: date(9, 20)))
        #expect(before.slack == TimeInterval(21600))
        #expect(!before.isFreeForToday)

        let after = engine.status(world: world, now: date(9, 20, 1))
        #expect(after.isLocked)
    }

    @Test("保管した目標は、ロックの理由にならない")
    func archivedGoal() {
        var goal = Goal.fixture()
        goal.isArchived = true
        #expect(!engine.status(world: World(goals: [goal]), now: now).isLocked)
    }

    // MARK: タスク

    @Test("着手リミットの前は、余裕として数える")
    func taskBeforeStartLimit() {
        // 締切 23:59、所要 2 時間なので、着手リミットは 21:59。
        let status = engine.status(world: World.exact(tasks: [.fixture()]), now: now)
        #expect(status.phase == .free(nextLockAt: date(9, 21, 59)))
        #expect(status.upcomingReasons.map(\.source) == [.task(uuid(100))])
        #expect(status.slack == TimeInterval(28740))
    }

    @Test("着手リミットを過ぎると、ロックされる")
    func taskAfterStartLimit() {
        let status = engine.status(world: World.exact(tasks: [.fixture()]), now: date(9, 22))
        #expect(status.isLocked)
        #expect(status.activeReasons.first?.dueAt == date(9, 23, 59))
    }

    @Test("締切を過ぎても、片づけるまでロックは続く")
    func overdueTaskStaysLocked() {
        #expect(engine.status(world: World.exact(tasks: [.fixture()]), now: date(11, 9)).isLocked)
    }

    @Test("完了または取り下げで、ロックが外れる")
    func resolvedTaskUnlocks() {
        let late = date(9, 22, 30)
        let completed = World.exact(tasks: [.fixture(completedAt: date(9, 22, 10))])
        let withdrawn = World.exact(tasks: [.fixture(withdrawnAt: date(9, 22, 10))])
        #expect(!engine.status(world: completed, now: late).isLocked)
        #expect(!engine.status(world: withdrawn, now: late).isLocked)
    }

    @Test("倍率を上げると、着手リミットが早まる")
    func bufferMovesStartLimitEarlier() {
        var world = World.exact(tasks: [.fixture()])
        world.preferences.buffer = .half
        // 2 時間 × 1.5 = 3 時間前。
        #expect(engine.status(world: world, now: now).phase == .free(nextLockAt: date(9, 20, 59)))
    }

    @Test("理由が複数あれば、すべて片づくまでロックが続く")
    func multipleReasons() {
        let world = World.exact(
            goals: [.fixture()],
            tasks: [.fixture()],
            sessions: [.fixture(startedAt: date(9, 9), minutes: 30)]
        )
        let status = engine.status(world: world, now: date(9, 22))
        #expect(status.isLocked)
        #expect(status.activeReasons.map(\.source) == [.task(uuid(100))])
    }

    // MARK: パス

    @Test("パスの間は、ロックが一時的に外れる")
    func passSuspendsLock() {
        var world = World(goals: [.fixture()])
        world.passUses = [PassUse(id: uuid(300), usedAt: date(9, 13, 50), minutes: 15)]

        let during = engine.status(world: world, now: now)
        #expect(during.phase == .onPass(until: date(9, 14, 5)))
        #expect(!during.isLocked)
        #expect(during.slack == TimeInterval(300))
        #expect(during.nextChangeAt == date(9, 14, 5))

        let after = engine.status(world: world, now: date(9, 14, 5))
        #expect(after.isLocked)
    }

    @Test("パスの残りは、今週使った回数で決まる")
    func passesRemaining() {
        var world = World(goals: [.fixture()])
        world.passUses = [
            // 先週(10/4 日曜)のぶんは数えない。
            PassUse(id: uuid(300), usedAt: date(4, 12), minutes: 15),
            PassUse(id: uuid(301), usedAt: date(6, 12), minutes: 15),
        ]
        let status = engine.status(world: world, now: now)
        #expect(status.passesRemaining == 1)
        #expect(status.canUsePass)

        world.passUses.append(PassUse(id: uuid(302), usedAt: date(7, 12), minutes: 15))
        #expect(!engine.status(world: world, now: now).canUsePass)
    }

    @Test("ロックされていなければ、パスは使えない")
    func passRequiresLock() {
        #expect(!engine.status(world: World(), now: now).canUsePass)
    }

    // MARK: ロック予報

    @Test("ロック予報は、今日の理由を時刻順に並べる")
    func forecastOrder() {
        let world = World.exact(
            goals: [
                .fixture(1, title: "院試"),
                .fixture(2, title: "TOEIC", lockStart: .timeOfDay(minutes: 18 * 60)),
            ],
            tasks: [
                .fixture(100, title: "レポート"),
                // 明後日が締切のものは、今日の予報に出ない。
                .fixture(101, title: "発表資料", dueAt: date(11, 18)),
                .fixture(102, title: "提出済み", dueAt: date(9, 12), estimateMinutes: 60, completedAt: date(9, 10)),
            ],
            sessions: [.fixture(startedAt: date(9, 9), minutes: 30)]
        )
        let forecast = engine.status(world: world, now: now).forecast
        #expect(forecast.map(\.title) == ["院試", "提出済み", "TOEIC", "レポート"])
        #expect(forecast.map(\.state) == [.cleared, .cleared, .upcoming, .upcoming])
    }

    @Test("次に状態が変わる時刻は、いちばん近い予定になる")
    func nextChangeAt() {
        let free = engine.status(world: World.exact(tasks: [.fixture()]), now: now)
        #expect(free.nextChangeAt == date(9, 21, 59))

        let nothing = engine.status(world: World(), now: now)
        #expect(nothing.nextChangeAt == date(10, 4))
    }

    // MARK: スクリーンタイムの層への指示

    @Test("計測が今日の分に達する時刻にも、見直しを予約する")
    func shieldPlanWakesAtFocusTarget() {
        let focus = ActiveFocus(goalID: uuid(1), startedAt: date(9, 13, 50))
        let world = World.exact(goals: [.fixture(dailyMinutes: 30)], activeFocus: focus)
        let status = engine.status(world: world, now: now)
        let plan = ShieldPlan(status: status, activeFocus: focus)
        #expect(plan.isLocked)
        // 13:50 に始めて 30 分なので、14:20 に達する。
        #expect(plan.wakeTimes == [date(9, 14, 20)])

        // 時間がたっても、達する時刻は変わらない(毎回の計算でずれると、予約をやり直すことになる)。
        let later = now.addingTimeInterval(15.4)
        let laterPlan = ShieldPlan(status: engine.status(world: world, now: later), activeFocus: focus)
        #expect(laterPlan == plan)
    }

    @Test("パスの間は、切れる時刻に見直しを予約する")
    func shieldPlanWakesAtPassEnd() {
        var world = World.exact(goals: [.fixture()])
        world.passUses = [PassUse(id: uuid(300), usedAt: date(9, 13, 50), minutes: 15)]
        let plan = ShieldPlan(status: engine.status(world: world, now: now))
        #expect(!plan.isLocked)
        #expect(plan.wakeTimes == [date(9, 14, 5)])
    }
}
