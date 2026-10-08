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

    // MARK: 1行入力からの提案

    /// 締切が明日の 23:59、所要 60 分の、名前がまだ空のタスク。
    private var blank: TaskItem {
        .fixture(title: "", dueAt: date(10, 23, 59), estimateMinutes: 60)
    }

    @Test("名前の欄に締切と所要時間を書くと、読み取った内容を提案する")
    func titleWithDetailsProducesSuggestion() async {
        let store = makeStore(blank, isNew: true)

        // 今日は金曜なので、「金曜まで」は今日の 23:59。
        await store.send(.binding(.set(\.task.title, "金曜までにレポート 2時間"))) {
            $0.task.title = "金曜までにレポート 2時間"
            $0.suggestion = QuickAdd(title: "レポート", dueAt: date(9, 23, 59), estimateMinutes: 120)
        }
        // 提案しただけで、タスクの内容はまだ変えない。
        #expect(store.state.task.dueAt == date(10, 23, 59))
        #expect(store.state.task.estimateMinutes == 60)
    }

    @Test("英語の書き方からも提案する")
    func englishTitleProducesSuggestion() async {
        let store = makeStore(blank, isNew: true)

        await store.send(.binding(.set(\.task.title, "Report by Friday 2h"))) {
            $0.task.title = "Report by Friday 2h"
            $0.suggestion = QuickAdd(title: "Report", dueAt: date(9, 23, 59), estimateMinutes: 120)
        }
    }

    @Test("画面の入力欄からは task 全体の書き換えとして届く。その形でも提案する")
    func titleEditedThroughTaskBindingProducesSuggestion() async {
        let store = makeStore(blank, isNew: true)
        var edited = blank
        edited.title = "Report by Friday 2h"

        // SwiftUI の `$store.task.title` は、`\.task.title` ではなく `\.task` の変更として送られる。
        await store.send(.binding(.set(\.task, edited))) {
            $0.task = edited
            $0.suggestion = QuickAdd(title: "Report", dueAt: date(9, 23, 59), estimateMinutes: 120)
        }
    }

    @Test("読み取れるものがない名前では、提案しない")
    func plainTitleProducesNoSuggestion() async {
        let store = makeStore(blank, isNew: true)

        await store.send(.binding(.set(\.task.title, "統計学のレポート"))) {
            $0.task.title = "統計学のレポート"
        }
        #expect(store.state.suggestion == nil)
    }

    @Test("締切や所要時間だけで名前が残らないときは、提案しない")
    func detailsWithoutTitleProduceNoSuggestion() async {
        let store = makeStore(blank, isNew: true)

        await store.send(.binding(.set(\.task.title, "明日 2時間"))) {
            $0.task.title = "明日 2時間"
        }
        #expect(store.state.suggestion == nil)
    }

    @Test("書き直して読み取れるものがなくなったら、提案を消す")
    func suggestionClearsWhenDetailsRemoved() async {
        let store = makeStore(blank, isNew: true)

        await store.send(.binding(.set(\.task.title, "レポート 90分"))) {
            $0.task.title = "レポート 90分"
            $0.suggestion = QuickAdd(title: "レポート", estimateMinutes: 90)
        }
        await store.send(.binding(.set(\.task.title, "レポート"))) {
            $0.task.title = "レポート"
            $0.suggestion = nil
        }
    }

    @Test("名前以外の欄を変えても、提案はそのまま残る")
    func otherFieldsKeepSuggestion() async {
        let store = makeStore(blank, isNew: true)

        await store.send(.binding(.set(\.task.title, "レポート 90分"))) {
            $0.task.title = "レポート 90分"
            $0.suggestion = QuickAdd(title: "レポート", estimateMinutes: 90)
        }
        await store.send(.binding(.set(\.task.estimateMinutes, 30))) {
            $0.task.estimateMinutes = 30
        }
        #expect(store.state.suggestion == QuickAdd(title: "レポート", estimateMinutes: 90))
    }

    @Test("提案を反映すると、名前、締切、所要時間が入れ替わり、提案は消える")
    func applySuggestionFillsFields() async {
        let store = makeStore(blank, isNew: true)

        await store.send(.binding(.set(\.task.title, "明日18時 ゼミの準備 1時間半"))) {
            $0.task.title = "明日18時 ゼミの準備 1時間半"
            $0.suggestion = QuickAdd(title: "ゼミの準備", dueAt: date(10, 18), estimateMinutes: 90)
        }
        await store.send(.applySuggestionTapped) {
            $0.task.title = "ゼミの準備"
            $0.task.dueAt = date(10, 18)
            $0.task.estimateMinutes = 90
            $0.suggestion = nil
        }
        await store.send(.saveTapped)
        await store.finish()

        #expect(spy.writes == [.saveTask(.fixture(title: "ゼミの準備", dueAt: date(10, 18), estimateMinutes: 90))])
    }

    @Test("提案に締切しかなければ、所要時間は変えない。所要時間しかなければ、締切は変えない")
    func applySuggestionKeepsMissingParts() async {
        let store = makeStore(blank, isNew: true)

        await store.send(.binding(.set(\.task.title, "10/12 17:00 奨学金の書類"))) {
            $0.task.title = "10/12 17:00 奨学金の書類"
            $0.suggestion = QuickAdd(title: "奨学金の書類", dueAt: date(12, 17))
        }
        await store.send(.applySuggestionTapped) {
            $0.task.title = "奨学金の書類"
            $0.task.dueAt = date(12, 17)
            $0.suggestion = nil
        }
        #expect(store.state.task.estimateMinutes == 60)

        await store.send(.binding(.set(\.task.title, "奨学金の書類 40分"))) {
            $0.task.title = "奨学金の書類 40分"
            $0.suggestion = QuickAdd(title: "奨学金の書類", estimateMinutes: 40)
        }
        await store.send(.applySuggestionTapped) {
            $0.task.title = "奨学金の書類"
            $0.task.estimateMinutes = 40
            $0.suggestion = nil
        }
        #expect(store.state.task.dueAt == date(12, 17))
    }

    @Test("読み取った所要時間は、5 分刻みに丸め、選べる範囲(5〜600 分)に収めて反映する")
    func applySuggestionRoundsAndClampsEstimate() async {
        let cases = [
            // 刻みに合わせて丸める。
            ("レポート 43分", 45),
            ("レポート 72分", 70),
            ("レポート 1.2時間", 70),
            ("レポート 58分", 60),
            // 範囲からはみ出す値は、端に寄せる。
            ("レポート 1分", 5),
            ("レポート 2分", 5),
            ("レポート 20時間", 600),
            ("レポート 601分", 600),
            // 範囲の端と、刻みどおりの値はそのまま。
            ("レポート 5分", 5),
            ("レポート 10時間", 600),
            ("レポート 90分", 90),
        ]
        let store = makeStore(blank, isNew: true)
        // 名前の欄を書き換えるたびの状態は追わず、反映した結果だけを確かめる。
        store.exhaustivity = .off

        for (text, expected) in cases {
            await store.send(.binding(.set(\.task.title, text)))
            await store.send(.applySuggestionTapped)
            #expect(store.state.task.estimateMinutes == expected, "\(text)")
            #expect(store.state.task.title == "レポート", "\(text)")
            #expect(store.state.suggestion == nil, "\(text)")
        }
    }

    @Test("提案がないときに反映を押しても、何も変わらない")
    func applyWithoutSuggestionDoesNothing() async {
        let store = makeStore(.fixture(), isNew: false)

        await store.send(.applySuggestionTapped)
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

    @Test("完了を押すと、いまの内容を保存してから、実際の所要時間を聞く画面を開くよう親に頼む")
    func completeSavesThenDelegatesToParent() async {
        let store = makeStore(.fixture())

        await store.send(.completeTapped)
        await store.receive(\.delegate, .complete(.fixture()))
        await store.finish()

        // 完了の印を付けるのは、次の画面で答えてから。ここでは、いまの内容を保存するだけ。
        #expect(spy.writes == [.saveTask(.fixture())])
        // 画面を閉じるのは親(完了の確認に入れ替える)。自分では閉じない。
        #expect(dismissed.value == 0)
    }

    @Test("編集してから完了を押すと、直した内容を保存し、同じ内容を親に渡す")
    func completeCarriesEdits() async {
        let store = makeStore(.fixture(title: "レポート", estimateMinutes: 60))

        await store.send(.binding(.set(\.task.title, "  統計学のレポート "))) {
            $0.task.title = "  統計学のレポート "
        }
        await store.send(.binding(.set(\.task.dueAt, date(12, 18)))) {
            $0.task.dueAt = date(12, 18)
        }
        await store.send(.binding(.set(\.task.estimateMinutes, 90))) {
            $0.task.estimateMinutes = 90
        }
        await store.send(.completeTapped)

        // 名前の前後の空白は除く。完了の確認をやめても、直した内容は残る。
        let edited = TaskItem.fixture(title: "統計学のレポート", dueAt: date(12, 18), estimateMinutes: 90)
        await store.receive(\.delegate, .complete(edited))
        await store.finish()

        #expect(spy.writes == [.saveTask(edited)])
        #expect(dismissed.value == 0)
    }

    @Test("取りかかった時刻は、完了を押しても消えずに引き継がれる")
    func completeKeepsStartedAt() async {
        let started = TaskItem.fixture(startedAt: date(9, 13, 10))
        let store = makeStore(started)

        await store.send(.completeTapped)
        await store.receive(\.delegate, .complete(started))
        await store.finish()

        #expect(spy.writes == [.saveTask(started)])
    }

    @Test("名前が空、または空白だけのときに完了を押しても、保存も依頼もしない")
    func completeIgnoredWithoutTitle() async {
        let store = makeStore(.fixture(title: ""), isNew: true)

        await store.send(.completeTapped)
        await store.send(.binding(.set(\.task.title, " \n "))) {
            $0.task.title = " \n "
        }
        await store.send(.completeTapped)
        await store.finish()

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
