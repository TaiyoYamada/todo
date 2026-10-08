import ComposableArchitecture
import Domain
import Foundation
import Testing

@testable import AppFeature

@MainActor
@Suite("目標の追加と編集")
struct GoalEditorFeatureTests {
    let spy = DatabaseSpy()
    let dismissed = LockIsolated(0)

    private func makeStore(_ goal: Goal, isNew: Bool = false) -> TestStoreOf<GoalEditorFeature> {
        TestStore(initialState: GoalEditorFeature.State(goal: goal, isNew: isNew)) {
            GoalEditorFeature()
        } withDependencies: {
            $0.database = spy.client
            $0.countDismiss(into: dismissed)
        }
    }

    // MARK: 保存できる条件

    @Test("名前が空、または空白だけなら保存できない")
    func cannotSaveWithoutTitle() {
        #expect(!GoalEditorFeature.State(goal: .fixture(title: ""), isNew: true).canSave)
        #expect(!GoalEditorFeature.State(goal: .fixture(title: "  \n\t"), isNew: true).canSave)
        #expect(GoalEditorFeature.State(goal: .fixture(title: "院試"), isNew: true).canSave)
    }

    @Test("やる曜日が1つもなければ保存できない")
    func cannotSaveWithoutWeekdays() {
        #expect(!GoalEditorFeature.State(goal: .fixture(weekdays: []), isNew: false).canSave)
        #expect(GoalEditorFeature.State(goal: .fixture(weekdays: [.monday]), isNew: false).canSave)
    }

    // MARK: 保存

    @Test("保存すると、名前の前後の空白を除いて保存し、画面を閉じる")
    func saveTrimsTitle() async {
        let store = makeStore(.fixture(title: "  院試\n"), isNew: true)

        await store.send(.saveTapped)
        await store.finish()

        #expect(spy.writes == [.saveGoal(.fixture(title: "院試"))])
        #expect(dismissed.value == 1)
    }

    @Test("入力した内容が、そのまま保存される")
    func saveKeepsEdits() async {
        let store = makeStore(.fixture(title: ""), isNew: true)

        await store.send(.binding(.set(\.goal.title, "TOEIC"))) {
            $0.goal.title = "TOEIC"
        }
        await store.send(.binding(.set(\.goal.dailyMinutes, 45))) {
            $0.goal.dailyMinutes = 45
        }
        await store.send(.saveTapped)
        await store.finish()

        #expect(spy.writes == [.saveGoal(.fixture(title: "TOEIC", dailyMinutes: 45))])
    }

    @Test("保存できない内容のときは、保存も画面を閉じることもしない")
    func saveIgnoredWhenInvalid() async {
        let store = makeStore(.fixture(title: "   "), isNew: true)

        await store.send(.saveTapped)
        await store.finish()

        #expect(spy.writes.isEmpty)
        #expect(dismissed.value == 0)
    }

    // MARK: やる曜日

    @Test("曜日を押すたびに、やる・やらないが入れ替わる")
    func weekdayToggles() async {
        let store = makeStore(.fixture(weekdays: [.monday, .wednesday]))

        await store.send(.weekdayTapped(.wednesday)) {
            $0.goal.weekdays = [.monday]
        }
        await store.send(.weekdayTapped(.friday)) {
            $0.goal.weekdays = [.monday, .friday]
        }
        await store.send(.weekdayTapped(.monday)) {
            $0.goal.weekdays = [.friday]
        }
        await store.send(.weekdayTapped(.friday)) {
            $0.goal.weekdays = []
        }
        // 全部外すと、保存できなくなる。
        #expect(!store.state.canSave)
    }

    // MARK: ロックが始まる時刻

    @Test("「朝から」の目標は、時刻の初期値として 20:00 を持つ")
    func defaultLockTime() {
        let state = GoalEditorFeature.State(goal: .fixture(), isNew: false)
        #expect(!state.locksAtTime)
        #expect(state.lockTimeMinutes == 20 * 60)
    }

    @Test("時刻を指定した目標を開くと、その時刻を引き継ぐ")
    func existingLockTimeIsLoaded() {
        let state = GoalEditorFeature.State(
            goal: .fixture(lockStart: .timeOfDay(minutes: 21 * 60 + 30)),
            isNew: false
        )
        #expect(state.locksAtTime)
        #expect(state.lockTimeMinutes == 21 * 60 + 30)
    }

    @Test("「時刻を指定」に切り替えると、覚えている時刻でロックする")
    func switchingToTimeUsesRememberedTime() async {
        let store = makeStore(.fixture())

        await store.send(.binding(.set(\.locksAtTime, true))) {
            $0.goal.lockStart = .timeOfDay(minutes: 20 * 60)
        }
        await store.send(.lockTimeChanged(minutes: 18 * 60 + 15)) {
            $0.lockTimeMinutes = 18 * 60 + 15
            $0.goal.lockStart = .timeOfDay(minutes: 18 * 60 + 15)
        }
        // 「朝から」に戻しても、選んだ時刻は覚えている。
        await store.send(.binding(.set(\.locksAtTime, false))) {
            $0.goal.lockStart = .dayStart
        }
        #expect(store.state.lockTimeMinutes == 18 * 60 + 15)

        await store.send(.binding(.set(\.locksAtTime, true))) {
            $0.goal.lockStart = .timeOfDay(minutes: 18 * 60 + 15)
        }
        await store.send(.saveTapped)
        await store.finish()

        #expect(spy.writes == [.saveGoal(.fixture(lockStart: .timeOfDay(minutes: 18 * 60 + 15)))])
    }

    // MARK: 削除、キャンセル

    @Test("削除すると、その目標を消して画面を閉じる")
    func deleteRemovesGoal() async {
        let store = makeStore(.fixture(7))

        await store.send(.deleteConfirmed)
        await store.finish()

        #expect(spy.writes == [.deleteGoal(uuid(7))])
        #expect(dismissed.value == 1)
    }

    @Test("キャンセルすると、保存せずに画面を閉じる")
    func cancelDismissesWithoutSaving() async {
        let store = makeStore(.fixture())

        await store.send(.binding(.set(\.goal.title, "変更"))) {
            $0.goal.title = "変更"
        }
        await store.send(.cancelTapped)
        await store.finish()

        #expect(spy.writes.isEmpty)
        #expect(dismissed.value == 1)
    }
}
