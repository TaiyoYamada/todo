import ComposableArchitecture
import Domain
import Foundation
import Testing
@testable import AppFeature

/// 止めた計測、または今日の分に達した計測を、同じ画面から続ける。
@MainActor
@Suite("集中の計測を続ける")
struct FocusFeatureContinueTests {
    /// 計測を始める時刻。10/9(金)14:00。
    let start = date(9, 14)
    /// 1日 30 分の目標。
    let goal = Goal.fixture()
    /// 現在の時刻。途中で進められる。最初は `start`。
    let now = LockIsolated(date(9, 14))
    let clock = TestClock()
    let spy = DatabaseSpy()

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
        }
    }

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
                .finishFocus([session(seconds: 20 * 60)]),
                .setActiveFocus(ActiveFocus(goalID: goal.id, startedAt: restart)),
                .finishFocus([session(1, startedAt: restart, seconds: 15 * 60)]),
            ]
        )
    }

    @Test("途中で止めてから続けると、残りの量から再開し、今日の分に達したところで止まる")
    func continueAfterPauseResumesTowardTarget() async {
        let store = makeStore()

        // 30 分のうち 10 分やって止める。
        await store.send(.task)
        await clock.advance(by: .seconds(10 * 60))
        now.setValue(start.addingTimeInterval(10 * 60))
        await store.send(.stopTapped) {
            $0.phase = .finished(.init(sessionSeconds: 10 * 60, reachedTarget: false))
        }

        // 5 分休んでから続ける。残りは 20 分。
        let restart = start.addingTimeInterval(15 * 60)
        now.setValue(restart)
        await store.send(.continueTapped) {
            $0.baseSeconds = 10 * 60
            $0.startedAt = restart
            $0.phase = .running
        }
        #expect(store.state.remainingAtStart == 20 * 60)
        #expect(store.state.endsAt == restart.addingTimeInterval(20 * 60))

        await clock.advance(by: .seconds(20 * 60 - 1))
        #expect(store.state.phase == .running)
        await clock.advance(by: .seconds(1))
        await store.receive(\.targetReached) {
            $0.phase = .finished(.init(sessionSeconds: 20 * 60, reachedTarget: true))
        }
        await store.finish()

        #expect(
            spy.writes == [
                .setActiveFocus(focus),
                .finishFocus([session(seconds: 10 * 60)]),
                .setActiveFocus(ActiveFocus(goalID: goal.id, startedAt: restart)),
                .finishFocus([session(1, startedAt: restart, seconds: 20 * 60)]),
            ]
        )
    }

    @Test("続けたあとにまた途中で止めても、今日の分に届くまでは達成にならない")
    func pausingAgainAfterContinueIsNotReached() async {
        let store = makeStore()

        await store.send(.task)
        now.setValue(start.addingTimeInterval(10 * 60))
        await store.send(.stopTapped) {
            $0.phase = .finished(.init(sessionSeconds: 10 * 60, reachedTarget: false))
        }
        await store.send(.continueTapped) {
            $0.baseSeconds = 10 * 60
            $0.startedAt = now.value
            $0.phase = .running
        }

        // さらに 5 分。合わせて 15 分で、30 分にはまだ届かない。
        now.setValue(start.addingTimeInterval(15 * 60))
        await store.send(.stopTapped) {
            $0.phase = .finished(.init(sessionSeconds: 5 * 60, reachedTarget: false))
        }
        await store.finish()
    }

    @Test("記録に残らない短い計測は、続けるときの「すでにやった量」に数えない")
    func continueAfterUnsavedSessionKeepsBase() async {
        let store = makeStore(baseSeconds: 10 * 60)

        await store.send(.task)
        now.setValue(start.addingTimeInterval(3))
        await store.send(.stopTapped) {
            $0.phase = .finished(.init(sessionSeconds: 3, reachedTarget: false))
        }
        await store.send(.continueTapped) {
            $0.startedAt = now.value
            $0.phase = .running
        }
        #expect(store.state.baseSeconds == 10 * 60)
        await store.cancelRemainingEffects()
    }

    @Test("保存済みの記録が共有の状態に届いていれば、続けるときはその量に合わせる")
    func continueUsesRecordedSecondsFromBoard() async {
        let store = makeStore()

        await store.send(.task)
        now.setValue(start.addingTimeInterval(10 * 60))
        await store.send(.stopTapped) {
            $0.phase = .finished(.init(sessionSeconds: 10 * 60, reachedTarget: false))
        }

        // この画面の外で 12 分ぶんの記録が増えていた(合わせて 22 分)。多いほうを信じる。
        let world = World.exact(
            goals: [goal],
            sessions: [session(seconds: 10 * 60), .fixture(201, startedAt: date(9, 9), minutes: 12)]
        )
        prepareBoard(world, now: now.value)
        await store.send(.continueTapped) {
            $0.baseSeconds = 22 * 60
            $0.startedAt = now.value
            $0.phase = .running
        }
        #expect(store.state.remainingAtStart == 8 * 60)
        await store.cancelRemainingEffects()
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
                .finishFocus([session(seconds: 30 * 60)]),
                .setActiveFocus(ActiveFocus(goalID: goal.id, startedAt: now.value)),
            ]
        )
    }
}
