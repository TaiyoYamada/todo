import ComposableArchitecture
import Domain
import Foundation
import Testing
@testable import AppFeature

@MainActor
@Suite("タスクの完了")
struct TaskCompletionFeatureTests {
    /// 10/9(金)14:00。
    let now = date(9, 14)
    let spy = DatabaseSpy()
    let dismissed = LockIsolated(0)

    private func makeStore(_ task: TaskItem, measuredMinutes: Int? = nil) -> TestStoreOf<TaskCompletionFeature> {
        TestStore(initialState: TaskCompletionFeature.State(task: task, measuredMinutes: measuredMinutes)) {
            TaskCompletionFeature()
        } withDependencies: {
            $0.fix(now: LockIsolated(now), database: spy)
            $0.countDismiss(into: dismissed)
        }
    }

    // MARK: 選択肢

    @Test("最初は、見積もりどおりの時間が選ばれている")
    func initialAnswerIsEstimate() {
        #expect(TaskCompletionFeature.State(task: .fixture(estimateMinutes: 90)).actualMinutes == 90)
    }

    @Test(
        "選択肢は、見積もりの半分・ちょうど・1.5倍・2倍・3倍を 5 分刻みに丸めたもの",
        arguments: [
            (60, [30, 60, 90, 120, 180]),
            (120, [60, 120, 180, 240, 360]),
            // 12 → 10、37 → 35 に丸める。
            (25, [10, 25, 35, 50, 75]),
            // 7 → 5、22 → 20 に丸める。
            (15, [5, 15, 20, 30, 45]),
            (600, [300, 600, 900, 1200, 1800]),
        ]
    )
    func optionsAreRounded(estimate: Int, expected: [Int]) {
        #expect(TaskCompletionFeature.State(task: .fixture(estimateMinutes: estimate)).options == expected)
    }

    @Test("丸めた結果が重なる選択肢は1つにまとめ、5 分より短くはしない")
    func optionsAreDeduplicated() {
        // 2, 5, 7, 10, 15 分 → 5, 5, 5, 10, 15 分。
        #expect(TaskCompletionFeature.State(task: .fixture(estimateMinutes: 5)).options == [5, 10, 15])
        // 5, 10, 15, 20, 30 分はそのまま。
        #expect(TaskCompletionFeature.State(task: .fixture(estimateMinutes: 10)).options == [5, 10, 15, 20, 30])
    }

    @Test("見積もりそのものは、必ず選択肢に入っている")
    func optionsContainEstimate() {
        for estimate in stride(from: 5, through: 600, by: 5) {
            let state = TaskCompletionFeature.State(task: .fixture(estimateMinutes: estimate))
            #expect(state.options.contains(estimate), "見積もり \(estimate) 分")
        }
    }

    @Test("選択肢は、短い順に並ぶ")
    func optionsAreSorted() {
        for estimate in stride(from: 5, through: 600, by: 5) {
            let options = TaskCompletionFeature.State(task: .fixture(estimateMinutes: estimate)).options
            #expect(options == options.sorted(), "見積もり \(estimate) 分")
            #expect(Set(options).count == options.count, "見積もり \(estimate) 分")
        }
    }

    // MARK: 取りかかってからの時間

    @Test("取りかかってからの時間が分かっていれば、見積もりではなく、それが最初に選ばれている")
    func initialAnswerIsMeasuredMinutes() {
        let state = TaskCompletionFeature.State(task: .fixture(estimateMinutes: 90), measuredMinutes: 50)
        #expect(state.actualMinutes == 50)
        #expect(state.measuredMinutes == 50)

        // 分かっていなければ、見積もりどおり。
        let unmeasured = TaskCompletionFeature.State(task: .fixture(estimateMinutes: 90), measuredMinutes: nil)
        #expect(unmeasured.actualMinutes == 90)
        #expect(unmeasured.measuredMinutes == nil)
    }

    @Test(
        "測った時間も選択肢に入り、短い順の正しい位置に並ぶ",
        arguments: [
            // 見積もり 60 分の選択肢(30, 60, 90, 120, 180)の間に入る。
            (60, 50, [30, 50, 60, 90, 120, 180]),
            // いちばん短い。
            (60, 5, [5, 30, 60, 90, 120, 180]),
            // いちばん長い。
            (60, 240, [30, 60, 90, 120, 180, 240]),
            // もとの選択肢と同じ値なら、増えない。
            (60, 90, [30, 60, 90, 120, 180]),
            (60, 60, [30, 60, 90, 120, 180]),
        ]
    )
    func optionsIncludeMeasuredMinutes(estimate: Int, measured: Int, expected: [Int]) {
        let state = TaskCompletionFeature.State(task: .fixture(estimateMinutes: estimate), measuredMinutes: measured)
        #expect(state.options == expected)
        // 最初に選ばれている値は、必ず選択肢の中にある。
        #expect(state.options.contains(state.actualMinutes))
    }

    @Test("何も選ばずに完了にすると、測った時間をそのまま保存する")
    func confirmWithoutChoosingUsesMeasuredMinutes() async {
        let task = TaskItem.fixture(estimateMinutes: 60, startedAt: date(9, 13, 10))
        let store = makeStore(task, measuredMinutes: 50)

        await store.send(.confirmTapped)
        await store.finish()

        // 取りかかった時刻は残したまま、完了の時刻と実際の所要時間を足す。
        #expect(
            spy.writes == [
                .saveTask(
                    .fixture(estimateMinutes: 60, startedAt: date(9, 13, 10), actualMinutes: 50, completedAt: now)
                ),
            ]
        )
        #expect(dismissed.value == 1)
    }

    @Test("測った時間があっても、別の選択肢を選べば、そちらを保存する")
    func measuredMinutesCanBeOverridden() async {
        let store = makeStore(.fixture(estimateMinutes: 60), measuredMinutes: 50)

        await store.send(.optionTapped(30)) {
            $0.actualMinutes = 30
        }
        await store.send(.confirmTapped)
        await store.finish()

        #expect(spy.writes == [.saveTask(.fixture(estimateMinutes: 60, actualMinutes: 30, completedAt: now))])
    }

    // MARK: 答える

    @Test("選択肢を押すと、実際の所要時間として選ばれる")
    func optionSelects() async {
        let store = makeStore(.fixture(estimateMinutes: 60))

        await store.send(.optionTapped(90)) {
            $0.actualMinutes = 90
        }
        await store.send(.optionTapped(30)) {
            $0.actualMinutes = 30
        }
    }

    @Test("完了にすると、完了した時刻と実際の所要時間を保存し、画面を閉じる")
    func confirmSavesCompletion() async {
        let store = makeStore(.fixture(estimateMinutes: 60))

        await store.send(.optionTapped(90)) {
            $0.actualMinutes = 90
        }
        await store.send(.confirmTapped)
        await store.finish()

        #expect(spy.writes == [.saveTask(.fixture(estimateMinutes: 60, actualMinutes: 90, completedAt: now))])
        #expect(dismissed.value == 1)
    }

    @Test("何も選ばずに完了にすると、見積もりどおりだったものとして保存する")
    func confirmWithoutChoosingUsesEstimate() async {
        let store = makeStore(.fixture(estimateMinutes: 45))

        await store.send(.confirmTapped)
        await store.finish()

        #expect(spy.writes == [.saveTask(.fixture(estimateMinutes: 45, actualMinutes: 45, completedAt: now))])
    }

    @Test("「まだ終わっていない」を押すと、保存せずに画面を閉じる")
    func cancelDismissesWithoutSaving() async {
        let store = makeStore(.fixture())

        await store.send(.cancelTapped)
        await store.finish()

        #expect(spy.writes.isEmpty)
        #expect(dismissed.value == 1)
    }
}
