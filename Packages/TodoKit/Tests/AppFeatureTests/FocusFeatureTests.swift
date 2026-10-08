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

    /// - Parameters:
    ///   - startedAt: 計測を始めた時刻。省けば `start`。
    ///   - dayStartHour: 1日の区切り。省けば初期値の 4 時。
    private func makeStore(
        baseSeconds: Int = 0,
        isResumed: Bool = false,
        startedAt: Date? = nil,
        dayStartHour: Int? = nil,
        dayEnd: Date = .distantFuture
    ) -> TestStoreOf<FocusFeature> {
        var world = World.exact(goals: [goal])
        if let dayStartHour {
            world.preferences.dayStartHour = dayStartHour
        }
        prepareBoard(world, now: now.value)
        return TestStore(
            initialState: FocusFeature.State(
                goal: goal,
                startedAt: startedAt ?? start,
                baseSeconds: baseSeconds,
                isResumed: isResumed,
                dayEnd: dayEnd
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

    @Test("今日の分に達すると自動で止まり、残りの秒数ちょうどの記録と、計測中の印を消すことを、1回で保存する")
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
                .finishFocus([session(seconds: 20 * 60)]),
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
                .finishFocus([session(seconds: 10 * 60)]),
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
                .finishFocus([session(seconds: 5 * 60)]),
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

        // 記録は残さないが、計測中の印は消す(記録なしの終了として 1 回だけ書く)。
        #expect(spy.writes == [.setActiveFocus(focus), .finishFocus([])])
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

        #expect(spy.writes == [.setActiveFocus(focus), .finishFocus([session(seconds: 5)])])
    }

    // MARK: 終えるときの保存

    @Test("終えるときは、記録を足すのと計測中の印を消すのを、別々には書かない")
    func finishWritesOnce() async {
        let store = makeStore()

        await store.send(.task)
        now.setValue(start.addingTimeInterval(10 * 60))
        await store.send(.stopTapped) {
            $0.phase = .finished(.init(sessionSeconds: 10 * 60, reachedTarget: false))
        }
        await store.finish()

        // 別々に書くと、その間だけ「記録も計測中もある」状態になり、進み具合を二重に数えてしまう。
        let finishing = spy.writes.dropFirst()
        #expect(finishing == [.finishFocus([session(seconds: 10 * 60)])])
        #expect(!spy.writes.contains(.setActiveFocus(nil)))
        #expect(!spy.writes.contains(.addSession(session(seconds: 10 * 60))))
    }

    // MARK: 1日の区切りをまたぐ

    @Test("1日の区切り(朝 4 時)をまたいだ計測は、区切りで2つの記録に分ける")
    func sessionAcrossDayBoundaryIsSplit() async {
        // 10/10 の 3:50 に始める。このアプリの1日としては、まだ 10/9。今日の分は終えていて、延長の計測。
        let begin = date(10, 3, 50)
        now.setValue(begin)
        let store = makeStore(baseSeconds: 30 * 60, startedAt: begin)

        await store.send(.task)
        // 4:10 に止める。区切りの前が 10 分、あとが 10 分。
        now.setValue(date(10, 4, 10))
        await store.send(.stopTapped) {
            $0.phase = .finished(.init(sessionSeconds: 20 * 60, reachedTarget: true))
        }
        await store.finish()

        // またいだあとのぶんは、新しい日(10/10)の記録として数えられる。
        #expect(
            spy.writes == [
                .setActiveFocus(ActiveFocus(goalID: goal.id, startedAt: begin)),
                .finishFocus([
                    session(0, startedAt: begin, seconds: 10 * 60),
                    session(1, startedAt: date(10, 4), seconds: 10 * 60),
                ]),
            ]
        )
    }

    @Test("達する前に日付が変わるなら、変わったあとに1日の量をやり終えるまで続ける")
    func targetMovesWhenDayChangesFirst() async {
        // 3:50 に始めて、残りは 30 分。4:00 に日付が変わり、そこから数え直しになるので、4:30 に達する。
        let begin = date(10, 3, 50)
        now.setValue(begin)
        let store = makeStore(startedAt: begin, dayEnd: date(10, 4))
        #expect(store.state.endsAt == date(10, 4, 30))

        await store.send(.task)
        now.setValue(date(10, 4, 30))
        await clock.advance(by: .seconds(40 * 60))
        await store.receive(\.targetReached) {
            $0.phase = .finished(.init(sessionSeconds: 40 * 60, reachedTarget: true))
        }
        await store.finish()

        #expect(
            spy.writes == [
                .setActiveFocus(ActiveFocus(goalID: goal.id, startedAt: begin)),
                .finishFocus([
                    session(0, startedAt: begin, seconds: 10 * 60),
                    session(1, startedAt: date(10, 4), seconds: 30 * 60),
                ]),
            ]
        )
    }

    @Test("日付が変わったあとに止めたら、変わってからの量だけで達したかを決める")
    func stoppingAfterDayChangeJudgesByNewDay() async {
        let begin = date(10, 3, 50)
        now.setValue(begin)
        let store = makeStore(startedAt: begin, dayEnd: date(10, 4))

        await store.send(.task)
        // 4:20 に止める。始めてから 30 分たったが、新しい日のぶんは 20 分で、まだ足りない。
        now.setValue(date(10, 4, 20))
        await store.send(.stopTapped) {
            $0.phase = .finished(.init(sessionSeconds: 30 * 60, reachedTarget: false))
        }
        await store.finish()
    }

    @Test("今日の分に達して自動で止まるときも、区切りをまたいでいれば分ける")
    func targetReachedAcrossDayBoundaryIsSplit() async {
        // 3:50 に始めて、残りは 30 分。4:20 に達する。
        let begin = date(10, 3, 50)
        now.setValue(begin)
        let store = makeStore(startedAt: begin)

        await store.send(.task)
        now.setValue(date(10, 4, 20))
        await clock.advance(by: .seconds(30 * 60))
        await store.receive(\.targetReached) {
            $0.phase = .finished(.init(sessionSeconds: 30 * 60, reachedTarget: true))
        }
        await store.finish()

        #expect(
            spy.writes.last == .finishFocus([
                session(0, startedAt: begin, seconds: 10 * 60),
                session(1, startedAt: date(10, 4), seconds: 20 * 60),
            ])
        )
    }

    @Test("区切りの時刻は設定に従う。0 時に設定していれば、0 時で分ける")
    func splitFollowsDayStartHourPreference() async {
        let begin = date(9, 23, 50)
        now.setValue(begin)
        let store = makeStore(baseSeconds: 30 * 60, startedAt: begin, dayStartHour: 0)

        await store.send(.task)
        now.setValue(date(10, 0, 5))
        await store.send(.stopTapped) {
            $0.phase = .finished(.init(sessionSeconds: 15 * 60, reachedTarget: true))
        }
        await store.finish()

        #expect(
            spy.writes.last == .finishFocus([
                session(0, startedAt: begin, seconds: 10 * 60),
                session(1, startedAt: date(10, 0), seconds: 5 * 60),
            ])
        )
    }

    @Test("暦の日付が変わっても、1日の区切りをまたいでいなければ分けない")
    func sessionAcrossMidnightIsNotSplit() async {
        // 区切りは朝 4 時。23:50 から 0:05 までは、同じ1日のうち。
        let begin = date(9, 23, 50)
        now.setValue(begin)
        let store = makeStore(baseSeconds: 30 * 60, startedAt: begin)

        await store.send(.task)
        now.setValue(date(10, 0, 5))
        await store.send(.stopTapped) {
            $0.phase = .finished(.init(sessionSeconds: 15 * 60, reachedTarget: true))
        }
        await store.finish()

        #expect(spy.writes.last == .finishFocus([session(0, startedAt: begin, seconds: 15 * 60)]))
    }

    @Test("区切りちょうどで止めた計測は、1つの記録のまま")
    func sessionEndingAtBoundaryIsNotSplit() async {
        let begin = date(10, 3, 50)
        now.setValue(begin)
        let store = makeStore(baseSeconds: 30 * 60, startedAt: begin)

        await store.send(.task)
        now.setValue(date(10, 4))
        await store.send(.stopTapped) {
            $0.phase = .finished(.init(sessionSeconds: 10 * 60, reachedTarget: true))
        }
        await store.finish()

        #expect(spy.writes.last == .finishFocus([session(0, startedAt: begin, seconds: 10 * 60)]))
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
        #expect(spy.writes == [.finishFocus([saved])])
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

        #expect(spy.writes == [.finishFocus([session(seconds: 30 * 60)])])
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

        #expect(spy.writes == [.finishFocus([session(seconds: 3 * 3600)])])
    }

    @Test("終わりのない計測を開き直したとき、3 時間以内なら続ける")
    func resumedOpenEndedSessionWithinCapKeepsRunning() async {
        now.setValue(start.addingTimeInterval(3 * 3600))
        let store = makeStore(baseSeconds: 30 * 60, isResumed: true)

        await store.send(.task)
        await store.finish()

        #expect(spy.writes.isEmpty)
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
