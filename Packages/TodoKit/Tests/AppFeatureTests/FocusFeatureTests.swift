import ComposableArchitecture
import Domain
import Foundation
import Testing

@testable import AppFeature

@MainActor
@Suite("集中の計測")
struct FocusFeatureTests {
    /// 計測を始める時刻。10/9(金)14:00。
    let start = date(9, 14)
    /// 1日 30 分の目標。
    let goal = Goal.fixture()
    /// 現在の時刻。途中で進められる。最初は `start`。
    let now = LockIsolated(date(9, 14))
    let clock = TestClock()
    let spy = DatabaseSpy()
    let dismissed = LockIsolated(0)

    private var focus: ActiveFocus { ActiveFocus(goalID: goal.id, startedAt: start) }

    private func session(_ id: Int = 0, startedAt: Date? = nil, seconds: Int) -> FocusSession {
        FocusSession(id: uuid(id), goalID: goal.id, startedAt: startedAt ?? start, seconds: seconds)
    }

    private func makeStore(baseSeconds: Int = 0, isResumed: Bool = false) -> TestStoreOf<FocusFeature> {
        prepareBoard(.exact(goals: [goal]), now: now.value)
        return TestStore(
            initialState: FocusFeature.State(
                goal: goal,
                startedAt: start,
                baseSeconds: baseSeconds,
                isResumed: isResumed
            )
        ) {
            FocusFeature()
        } withDependencies: {
            $0.fix(now: now, database: spy)
            $0.continuousClock = clock
            $0.countDismiss(into: dismissed)
        }
    }

    // MARK: 残りの量

    @Test("残りの量と終わる時刻は、今日すでにやった量から決まる")
    func remainingDependsOnBase() {
        let fresh = FocusFeature.State(goal: goal, startedAt: start, baseSeconds: 0)
        #expect(fresh.remainingAtStart == 30 * 60)
        #expect(fresh.endsAt == date(9, 14, 30))

        let partlyDone = FocusFeature.State(goal: goal, startedAt: start, baseSeconds: 10 * 60)
        #expect(partlyDone.remainingAtStart == 20 * 60)
        #expect(partlyDone.endsAt == date(9, 14, 20))

        // 今日の分を終えたあとの計測には、終わりがない。
        let done = FocusFeature.State(goal: goal, startedAt: start, baseSeconds: 45 * 60)
        #expect(done.remainingAtStart == 0)
        #expect(done.endsAt == nil)
    }

    // MARK: 始める

    @Test("始めると、計測中であることを保存する")
    func startPersistsActiveFocus() async {
        let store = makeStore()

        await store.send(.task)
        await clock.advance(by: .seconds(1))

        #expect(spy.writes == [.setActiveFocus(focus)])
        // 残っているのは、今日の分に達するのを待つ処理だけ。
        await store.cancelRemainingEffects()
    }

    // MARK: 今日の分に達する

    @Test("今日の分に達すると自動で止まり、残りの秒数ちょうどを記録して、計測中の印を消す")
    func targetReachedFinishesWithRemainingSeconds() async {
        // 今日すでに 10 分やっている。残りは 20 分。
        let store = makeStore(baseSeconds: 10 * 60)

        await store.send(.task)
        await clock.advance(by: .seconds(20 * 60 - 1))
        #expect(store.state.phase == .running)

        // 知らせが少し遅れて届いても、記録は達した時刻で止まる。
        now.setValue(start.addingTimeInterval(20 * 60 + 0.7))
        await clock.advance(by: .seconds(1))
        await store.receive(\.targetReached) {
            $0.phase = .finished(.init(sessionSeconds: 20 * 60, reachedTarget: true))
        }
        await store.finish()

        #expect(
            spy.writes == [
                .setActiveFocus(focus),
                .addSession(session(seconds: 20 * 60)),
                .setActiveFocus(nil),
            ]
        )
    }

    // MARK: 途中で止める

    @Test("途中で止めると、そこまでの時間を記録する")
    func stopEarlySavesElapsed() async {
        let store = makeStore()

        await store.send(.task)
        await clock.advance(by: .seconds(10 * 60))
        now.setValue(start.addingTimeInterval(10 * 60))
        await store.send(.stopTapped) {
            $0.phase = .finished(.init(sessionSeconds: 10 * 60, reachedTarget: false))
        }
        // 今日の分に達したときの知らせも取り消されているので、残っている処理はない。
        await store.finish()

        #expect(
            spy.writes == [
                .setActiveFocus(focus),
                .addSession(session(seconds: 10 * 60)),
                .setActiveFocus(nil),
            ]
        )
    }

    @Test("止めた時点で今日の分に届いていれば、達成として扱う")
    func stopAfterReachingTargetCountsAsReached() async {
        // 今日の分は終わっていて、延長の計測をしている。
        let store = makeStore(baseSeconds: 30 * 60)

        await store.send(.task)
        now.setValue(start.addingTimeInterval(5 * 60))
        await store.send(.stopTapped) {
            $0.phase = .finished(.init(sessionSeconds: 5 * 60, reachedTarget: true))
        }
        await store.finish()

        #expect(
            spy.writes == [
                .setActiveFocus(focus),
                .addSession(session(seconds: 5 * 60)),
                .setActiveFocus(nil),
            ]
        )
    }

    @Test("5 秒に満たない計測は、押し間違いとして記録しない")
    func shortSessionIsNotSaved() async {
        let store = makeStore()

        await store.send(.task)
        now.setValue(start.addingTimeInterval(4))
        await store.send(.stopTapped) {
            $0.phase = .finished(.init(sessionSeconds: 4, reachedTarget: false))
        }
        await store.finish()

        // 記録は残さないが、計測中の印は消す。
        #expect(spy.writes == [.setActiveFocus(focus), .setActiveFocus(nil)])
    }

    @Test("ちょうど 5 秒の計測は、記録する")
    func fiveSecondSessionIsSaved() async {
        let store = makeStore()

        await store.send(.task)
        now.setValue(start.addingTimeInterval(5))
        await store.send(.stopTapped) {
            $0.phase = .finished(.init(sessionSeconds: 5, reachedTarget: false))
        }
        await store.finish()

        #expect(spy.writes == [.setActiveFocus(focus), .addSession(session(seconds: 5)), .setActiveFocus(nil)])
    }

    // MARK: アプリを開き直す

    @Test("開き直したとき、今日の分に達する時刻を過ぎていれば、その時刻で止まったものとして記録する")
    func resumedPastTargetEndsAtTargetTime() async {
        // 14:00 に始めて残り 20 分。アプリを閉じ、2 時間後に開き直した。
        now.setValue(start.addingTimeInterval(2 * 3600))
        let store = makeStore(baseSeconds: 10 * 60, isResumed: true)

        await store.send(.task)
        // 待つ時間は 0 秒。テスト用の時計は、進めるまで待ちを解かない。
        await clock.advance()
        await store.receive(\.targetReached) {
            $0.phase = .finished(.init(sessionSeconds: 20 * 60, reachedTarget: true))
        }
        await store.finish()

        let saved = session(seconds: 20 * 60)
        #expect(saved.endedAt == date(9, 14, 20))
        // 計測中の印はすでに保存済みなので、書き直さない。
        #expect(spy.writes == [.addSession(saved), .setActiveFocus(nil)])
    }

    @Test("開き直したとき、今日の分にまだ達していなければ、残りの時間だけ待つ")
    func resumedBeforeTargetWaitsForRemainder() async {
        // 残り 30 分のうち、12 分たったところで開き直した。
        now.setValue(start.addingTimeInterval(12 * 60))
        let store = makeStore(isResumed: true)

        await store.send(.task)
        await clock.advance(by: .seconds(18 * 60 - 1))
        #expect(store.state.phase == .running)
        #expect(spy.writes.isEmpty)

        await clock.advance(by: .seconds(1))
        await store.receive(\.targetReached) {
            $0.phase = .finished(.init(sessionSeconds: 30 * 60, reachedTarget: true))
        }
        await store.finish()

        #expect(spy.writes == [.addSession(session(seconds: 30 * 60)), .setActiveFocus(nil)])
    }

    @Test("終わりのない計測を開き直したとき、3 時間を超えていれば 3 時間で打ち切る")
    func resumedOpenEndedSessionIsCapped() async {
        // 今日の分を終えたあとの延長を、止め忘れて 5 時間たった。
        now.setValue(start.addingTimeInterval(5 * 3600))
        let store = makeStore(baseSeconds: 30 * 60, isResumed: true)

        await store.send(.task) {
            $0.phase = .finished(.init(sessionSeconds: 3 * 3600, reachedTarget: true))
        }
        await store.finish()

        #expect(spy.writes == [.addSession(session(seconds: 3 * 3600)), .setActiveFocus(nil)])
    }

    @Test("終わりのない計測を開き直したとき、3 時間以内なら続ける")
    func resumedOpenEndedSessionWithinCapKeepsRunning() async {
        now.setValue(start.addingTimeInterval(3 * 3600))
        let store = makeStore(baseSeconds: 30 * 60, isResumed: true)

        await store.send(.task)
        await store.finish()

        #expect(spy.writes.isEmpty)
    }

    // MARK: 続ける

    @Test("今日の分を終えたあとに続けると、終わりのない計測が始まる")
    func continueAfterTargetStartsOpenEndedSession() async {
        let store = makeStore(baseSeconds: 10 * 60)

        await store.send(.task)
        await clock.advance(by: .seconds(20 * 60))
        await store.receive(\.targetReached) {
            $0.phase = .finished(.init(sessionSeconds: 20 * 60, reachedTarget: true))
        }

        // 1 分休んでから続ける。
        let restart = start.addingTimeInterval(21 * 60)
        now.setValue(restart)
        await store.send(.continueTapped) {
            $0.baseSeconds = 30 * 60
            $0.startedAt = restart
            $0.phase = .running
        }
        #expect(store.state.endsAt == nil)

        // 終わりがないので、どれだけ待っても自動では止まらない。
        await clock.advance(by: .seconds(3600))
        #expect(store.state.phase == .running)

        now.setValue(restart.addingTimeInterval(15 * 60))
        await store.send(.stopTapped) {
            $0.phase = .finished(.init(sessionSeconds: 15 * 60, reachedTarget: true))
        }
        await store.finish()

        #expect(
            spy.writes == [
                .setActiveFocus(focus),
                .addSession(session(seconds: 20 * 60)),
                .setActiveFocus(nil),
                .setActiveFocus(ActiveFocus(goalID: goal.id, startedAt: restart)),
                .addSession(session(1, startedAt: restart, seconds: 15 * 60)),
                .setActiveFocus(nil),
            ]
        )
    }

    @Test("開き直して終えた計測から続けると、新しい計測として保存し直す")
    func continueAfterResumedSessionPersistsNewFocus() async {
        now.setValue(start.addingTimeInterval(2 * 3600))
        let store = makeStore(isResumed: true)

        await store.send(.task)
        await clock.advance()
        await store.receive(\.targetReached) {
            $0.phase = .finished(.init(sessionSeconds: 30 * 60, reachedTarget: true))
        }
        await store.send(.continueTapped) {
            $0.baseSeconds = 30 * 60
            $0.startedAt = now.value
            $0.isResumed = false
            $0.phase = .running
        }
        await store.finish()

        #expect(
            spy.writes == [
                .addSession(session(seconds: 30 * 60)),
                .setActiveFocus(nil),
                .setActiveFocus(ActiveFocus(goalID: goal.id, startedAt: now.value)),
            ]
        )
    }

    // MARK: 閉じる、二重の操作

    @Test("閉じるを押すと、画面を閉じる")
    func closeDismisses() async {
        let store = makeStore()

        await store.send(.closeTapped)
        await store.finish()

        #expect(dismissed.value == 1)
        #expect(spy.writes.isEmpty)
    }

    @Test("終えたあとの「止める」や「始める」は、何もしない")
    func actionsAfterFinishAreIgnored() async {
        let store = makeStore()

        await store.send(.task)
        now.setValue(start.addingTimeInterval(60))
        await store.send(.stopTapped) {
            $0.phase = .finished(.init(sessionSeconds: 60, reachedTarget: false))
        }
        await store.finish()
        let writes = spy.writes

        await store.send(.stopTapped)
        await store.send(.task)
        await store.send(.targetReached)
        await store.finish()

        #expect(spy.writes == writes)
    }
}
