import Domain
import Foundation
import NotificationClient
import Testing
@testable import AppFeature

@Suite("ロックの前触れの通知")
struct AppFeatureWarningTests {
    /// 10/9(金)14:00。
    let now = date(9, 14)
    /// 1日 30 分の目標。朝からロックする。
    let goal = Goal.fixture()

    private func status(_ world: World) -> LockStatus {
        LockEngine(calendar: tokyo).status(world: world, now: now)
    }

    private func warnings(_ world: World) -> [LockNotification] {
        AppFeature.warnings(for: status(world))
    }

    @Test("30 分より先のロックには、30 分前の前触れと、始まったときの通知を予約する")
    func warningsForDistantLock() {
        // 着手リミットは 16:00。いまは 14:00。
        let notifications = warnings(.exact(tasks: [.fixture(dueAt: date(9, 18))]))

        #expect(
            notifications.map(\.id) == [
                "warn-task(00000000-0000-0000-0000-000000000100)",
                "start-task(00000000-0000-0000-0000-000000000100)",
            ]
        )
        #expect(notifications.map(\.fireAt) == [date(9, 15, 30), date(9, 16)])
        // 何のロックかが分かるよう、本文に名前を入れる。
        #expect(notifications.allSatisfy { $0.body.contains("レポート") })
        #expect(notifications.allSatisfy { !$0.title.isEmpty })
    }

    @Test("目標のロックにも、同じように予約する")
    func warningsForGoal() {
        let notifications = warnings(.exact(goals: [.fixture(lockStart: .timeOfDay(minutes: 20 * 60))]))

        #expect(
            notifications.map(\.id) == [
                "warn-goal(00000000-0000-0000-0000-000000000001)",
                "start-goal(00000000-0000-0000-0000-000000000001)",
            ]
        )
        #expect(notifications.map(\.fireAt) == [date(9, 19, 30), date(9, 20)])
    }

    @Test("30 分以内に始まるロックには、前触れは出さず、始まったときの通知だけを予約する")
    func warningsSkipLeadWhenTooClose() {
        let world = World.exact(
            tasks: [
                // 着手リミットは 14:20。前触れの時刻(13:50)はもう過ぎている。
                .fixture(100, title: "A", dueAt: date(9, 16, 20)),
                // 着手リミットは 14:30。前触れの時刻がちょうどいま。
                .fixture(101, title: "B", dueAt: date(9, 16, 30)),
                // 着手リミットは 14:31。前触れは 1 分後。
                .fixture(102, title: "C", dueAt: date(9, 16, 31)),
            ]
        )
        let notifications = warnings(world)

        #expect(
            notifications.map(\.id) == [
                "start-task(00000000-0000-0000-0000-000000000100)",
                "start-task(00000000-0000-0000-0000-000000000101)",
                "warn-task(00000000-0000-0000-0000-000000000102)",
                "start-task(00000000-0000-0000-0000-000000000102)",
            ]
        )
        #expect(
            notifications.map(\.fireAt) == [date(9, 14, 20), date(9, 14, 30), date(9, 14, 1), date(9, 14, 31)]
        )
    }

    @Test("すでに始まっているロックと、片づけたものには予約しない")
    func warningsIgnoreActiveAndClosed() {
        let world = World.exact(
            goals: [goal],
            tasks: [
                .fixture(100, dueAt: date(9, 15)),
                .fixture(101, dueAt: date(9, 20), completedAt: date(9, 10)),
                .fixture(102, dueAt: date(9, 20), withdrawnAt: date(9, 10)),
            ]
        )
        #expect(status(world).activeReasons.count == 2)
        #expect(warnings(world).isEmpty)
        #expect(warnings(World()).isEmpty)
    }

    @Test("予約するのは、近い順に 8 件のロックまで")
    func warningsAreLimited() {
        // 10/10 から 10/19 まで、毎日 17:00 に着手リミットが来る。
        let tasks = (10 ... 19).map { day in
            TaskItem.fixture(100 + day, title: "\(day)日", dueAt: date(day, 18), estimateMinutes: 60)
        }
        let notifications = warnings(.exact(tasks: tasks))

        #expect(notifications.count == 16)
        #expect(notifications.first?.fireAt == date(10, 16, 30))
        #expect(notifications.last?.fireAt == date(17, 17))
    }
}
