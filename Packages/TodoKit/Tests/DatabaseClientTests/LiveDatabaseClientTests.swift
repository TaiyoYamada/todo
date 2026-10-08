import Domain
import Foundation
import Testing
@testable import DatabaseClient

/// 実際の SQLite(テストごとの一時データベース)に対して確かめる。
@Suite("SQLite への保存")
struct LiveDatabaseClientTests {
    let client: DatabaseClient

    init() throws {
        client = try .live(database: openAppDatabase())
    }

    private func currentWorld() async -> World? {
        var iterator = client.observeWorld().makeAsyncIterator()
        return await iterator.next()
    }

    @Test("何も保存していなければ、空で、設定は初期値")
    func emptyDatabase() async {
        #expect(await currentWorld() == World())
    }

    @Test("保存したものが、同じ値で読める")
    func roundTrip() async throws {
        let goal = Goal(
            id: uuid(1),
            title: "院試",
            symbol: "function",
            tint: .teal,
            dailyMinutes: 45,
            weekdays: [.monday, .wednesday, .saturday],
            lockStart: .timeOfDay(minutes: 20 * 60),
            createdAt: at(1000)
        )
        let task = TaskItem(id: uuid(2), title: "レポート", dueAt: at(9000), estimateMinutes: 90, createdAt: at(1000))
        let session = FocusSession(id: uuid(3), goalID: goal.id, startedAt: at(2000), seconds: 1500)
        let passUse = PassUse(id: uuid(4), usedAt: at(3000), minutes: 15)
        var preferences = Preferences()
        preferences.dayStartHour = 5
        preferences.buffer = .half
        preferences.hasCompletedOnboarding = true

        try await client.saveGoal(goal)
        try await client.saveTask(task)
        try await client.addSession(session)
        try await client.addPassUse(passUse)
        try await client.setActiveFocus(ActiveFocus(goalID: goal.id, startedAt: at(4000)))
        try await client.savePreferences(preferences)

        let world = await currentWorld()
        #expect(world?.goals == [goal])
        #expect(world?.tasks == [task])
        #expect(world?.sessions == [session])
        #expect(world?.passUses == [passUse])
        #expect(world?.activeFocus == ActiveFocus(goalID: goal.id, startedAt: at(4000)))
        #expect(world?.preferences == preferences)
    }

    @Test("目標を上書きしても、その記録は消えない")
    func updatingGoalKeepsSessions() async throws {
        var goal = Goal(id: uuid(1), title: "院試", createdAt: at(1000))
        try await client.saveGoal(goal)
        try await client.addSession(FocusSession(id: uuid(3), goalID: goal.id, startedAt: at(2000), seconds: 600))

        goal.title = "大学院入試"
        goal.dailyMinutes = 60
        try await client.saveGoal(goal)

        let world = await currentWorld()
        #expect(world?.goals == [goal])
        #expect(world?.sessions.count == 1)
    }

    @Test("目標を消すと、その記録と計測中の状態も消える")
    func deletingGoalCascades() async throws {
        let goal = Goal(id: uuid(1), title: "院試", createdAt: at(1000))
        try await client.saveGoal(goal)
        try await client.addSession(FocusSession(id: uuid(3), goalID: goal.id, startedAt: at(2000), seconds: 600))
        try await client.setActiveFocus(ActiveFocus(goalID: goal.id, startedAt: at(4000)))

        try await client.deleteGoal(goal.id)

        let world = await currentWorld()
        #expect(world?.goals.isEmpty == true)
        #expect(world?.sessions.isEmpty == true)
        #expect(world?.activeFocus == nil)
    }

    @Test("タスクの完了と削除")
    func taskLifecycle() async throws {
        var task = TaskItem(id: uuid(2), title: "レポート", dueAt: at(9000), createdAt: at(1000))
        try await client.saveTask(task)

        task.startedAt = at(2000)
        task.completedAt = at(5000)
        task.actualMinutes = 95
        try await client.saveTask(task)
        #expect(await currentWorld()?.tasks == [task])

        try await client.deleteTask(task.id)
        #expect(await currentWorld()?.tasks.isEmpty == true)
    }

    @Test("変更のたびに、新しい値が流れる")
    func observationEmitsOnChange() async throws {
        var iterator = client.observeWorld().makeAsyncIterator()
        #expect(await iterator.next()?.goals.isEmpty == true)

        try await client.saveGoal(Goal(id: uuid(1), title: "院試", createdAt: at(1000)))
        #expect(await iterator.next()?.goals.map(\.title) == ["院試"])
    }

    @Test("全体の置き換え")
    func replaceAll() async throws {
        try await client.saveGoal(Goal(id: uuid(9), title: "古い目標", createdAt: at(1)))

        let goal = Goal(id: uuid(1), title: "院試", createdAt: at(1000))
        let world = World(
            goals: [goal],
            tasks: [TaskItem(id: uuid(2), title: "レポート", dueAt: at(9000), createdAt: at(1000))],
            sessions: [FocusSession(id: uuid(3), goalID: goal.id, startedAt: at(2000), seconds: 600)],
            passUses: [PassUse(id: uuid(4), usedAt: at(3000), minutes: 15)],
            preferences: Preferences(weeklyPassLimit: 3)
        )
        try await client.replaceAll(world)

        #expect(await currentWorld() == world)
    }
}

private func uuid(_ value: Int) -> UUID {
    // テスト用の決まった形の文字列なので、必ず UUID になる。
    UUID(uuidString: "00000000-0000-0000-0000-" + String(format: "%012d", value)) ?? UUID()
}

private func at(_ seconds: TimeInterval) -> Date {
    Date(timeIntervalSince1970: 1_780_000_000 + seconds)
}
