import ComposableArchitecture
import Domain
import Foundation
import Testing

@testable import AppFeature

@MainActor
@Suite("タスクの追加と編集")
struct TaskEditorFeatureTests {
    /// 10/9(金)14:00。
    let now = date(9, 14)
    let spy = DatabaseSpy()
    let dismissed = LockIsolated(0)

    private func makeStore(
        _ task: TaskItem,
        isNew: Bool = false,
        world: World = .exact()
    ) -> TestStoreOf<TaskEditorFeature> {
        prepareBoard(world, now: now)
        return TestStore(initialState: TaskEditorFeature.State(task: task, isNew: isNew)) {
            TaskEditorFeature()
        } withDependencies: {
            $0.fix(now: LockIsolated(now), database: spy)
            $0.countDismiss(into: dismissed)
        }
    }

    // MARK: 保存

    @Test("名前が空、または空白だけなら保存できない")
    func cannotSaveWithoutTitle() {
        prepareBoard(.exact(), now: now)
        #expect(!TaskEditorFeature.State(task: .fixture(title: ""), isNew: true).canSave)
        #expect(!TaskEditorFeature.State(task: .fixture(title: " \n "), isNew: true).canSave)
        #expect(TaskEditorFeature.State(task: .fixture(title: "レポート"), isNew: true).canSave)
    }

    @Test("保存すると、名前の前後の空白を除いて保存し、画面を閉じる")
    func saveTrimsTitle() async {
        let store = makeStore(.fixture(title: " レポート  "), isNew: true)

        await store.send(.saveTapped)
        await store.finish()

        #expect(spy.writes == [.saveTask(.fixture(title: "レポート"))])
        #expect(dismissed.value == 1)
    }

    @Test("入力した内容が、そのまま保存される")
    func saveKeepsEdits() async {
        let store = makeStore(.fixture(title: ""), isNew: true)

        await store.send(.binding(.set(\.task.title, "発表資料"))) {
            $0.task.title = "発表資料"
        }
        await store.send(.binding(.set(\.task.dueAt, date(12, 18)))) {
            $0.task.dueAt = date(12, 18)
        }
        await store.send(.binding(.set(\.task.estimateMinutes, 180))) {
            $0.task.estimateMinutes = 180
        }
        await store.send(.saveTapped)
        await store.finish()

        #expect(spy.writes == [.saveTask(.fixture(title: "発表資料", dueAt: date(12, 18), estimateMinutes: 180))])
    }

    @Test("保存できない内容のときは、保存も画面を閉じることもしない")
    func saveIgnoredWhenInvalid() async {
        let store = makeStore(.fixture(title: ""), isNew: true)

        await store.send(.saveTapped)
        await store.finish()

        #expect(spy.writes.isEmpty)
        #expect(dismissed.value == 0)
    }

    // MARK: 着手リミット

    @Test("着手リミットは、締切から「所要時間 × 倍率」を引いた時刻")
    func startLimitUsesEstimateFactor() {
        // 23:59 が締切で、所要 120 分。
        prepareBoard(.exact(), now: now)
        #expect(TaskEditorFeature.State(task: .fixture(), isNew: true).startLimit == date(9, 21, 59))

        // 倍率 1.5 なら 180 分前。
        var world = World.exact()
        world.preferences.buffer = .half
        prepareBoard(world, now: now)
        #expect(TaskEditorFeature.State(task: .fixture(), isNew: true).startLimit == date(9, 20, 59))
    }

    @Test("所要時間を変えると、着手リミットも動く")
    func startLimitFollowsEdits() async {
        let store = makeStore(.fixture())
        #expect(!store.state.locksImmediately)

        await store.send(.binding(.set(\.task.estimateMinutes, 600))) {
            $0.task.estimateMinutes = 600
        }
        // 23:59 の 10 時間前は 13:59。いまは 14:00 なので、もう過ぎている。
        #expect(store.state.startLimit == date(9, 13, 59))
        #expect(store.state.locksImmediately)
    }

    @Test("着手リミットが現在の時刻ちょうどなら、すぐにロックされる扱いになる")
    func locksImmediatelyAtBoundary() {
        prepareBoard(.exact(), now: now)
        // 所要 120 分。締切が 16:00 なら、着手リミットはいまと同じ 14:00。
        let atLimit = TaskEditorFeature.State(task: .fixture(dueAt: date(9, 16)), isNew: true)
        #expect(atLimit.locksImmediately)

        let justBefore = TaskEditorFeature.State(task: .fixture(dueAt: date(9, 16, 1)), isNew: true)
        #expect(!justBefore.locksImmediately)
    }

    @Test("片づけたタスクは、着手リミットを過ぎていてもロックの扱いにならない")
    func closedTaskNeverLocks() {
        prepareBoard(.exact(), now: now)
        let completed = TaskEditorFeature.State(
            task: .fixture(dueAt: date(9, 10), completedAt: date(9, 9)),
            isNew: false
        )
        #expect(!completed.locksImmediately)

        let withdrawn = TaskEditorFeature.State(
            task: .fixture(dueAt: date(9, 10), withdrawnAt: date(9, 9)),
            isNew: false
        )
        #expect(!withdrawn.locksImmediately)
    }

    // MARK: 完了、取り下げ、戻す

    @Test("完了を押すと、実際の所要時間を聞く画面を開くよう親に頼む")
    func completeDelegatesToParent() async {
        let store = makeStore(.fixture())

        await store.send(.completeTapped)
        await store.receive(\.delegate, .complete(uuid(100)))
        await store.finish()

        // 完了の保存は、次の画面で答えてから行う。
        #expect(spy.writes.isEmpty)
        #expect(dismissed.value == 0)
    }

    @Test("取り下げると、取り下げた時刻を付けて保存し、画面を閉じる")
    func withdrawSavesTimestamp() async {
        let store = makeStore(.fixture())

        await store.send(.withdrawConfirmed)
        await store.finish()

        #expect(spy.writes == [.saveTask(.fixture(withdrawnAt: now))])
        #expect(dismissed.value == 1)
    }

    @Test("完了したタスクを未完了に戻すと、完了の時刻と実際の所要時間が消える")
    func reopenCompletedTask() async {
        let store = makeStore(.fixture(actualMinutes: 150, completedAt: date(9, 12)))

        await store.send(.reopenTapped)
        await store.finish()

        #expect(spy.writes == [.saveTask(.fixture())])
        #expect(dismissed.value == 1)
    }

    @Test("取り下げたタスクを未完了に戻すと、取り下げた時刻が消える")
    func reopenWithdrawnTask() async {
        let store = makeStore(.fixture(withdrawnAt: date(9, 12)))

        await store.send(.reopenTapped)
        await store.finish()

        #expect(spy.writes == [.saveTask(.fixture())])
    }

    // MARK: 削除、キャンセル

    @Test("削除すると、そのタスクを消して画面を閉じる")
    func deleteRemovesTask() async {
        let store = makeStore(.fixture(105))

        await store.send(.deleteConfirmed)
        await store.finish()

        #expect(spy.writes == [.deleteTask(uuid(105))])
        #expect(dismissed.value == 1)
    }

    @Test("キャンセルすると、保存せずに画面を閉じる")
    func cancelDismissesWithoutSaving() async {
        let store = makeStore(.fixture())

        await store.send(.cancelTapped)
        await store.finish()

        #expect(spy.writes.isEmpty)
        #expect(dismissed.value == 1)
    }
}
