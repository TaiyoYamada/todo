import ComposableArchitecture
import DatabaseClient
import Domain
import Foundation
import LiveActivityClient

/// 目標の今日の分を進める、時間の計測。
///
/// 今日の分に達した時点で自動的に止まる。アプリを閉じても計測は続き、
/// 次に開いたときに「達した時刻で止まった」ものとして記録する。
@Reducer
struct FocusFeature {
    @ObservableState
    struct State: Equatable {
        @SharedReader(.board) var board
        let goal: Goal
        var startedAt: Date
        /// この計測を始める前に、今日すでにやっていた量(秒)。
        var baseSeconds: Int
        /// アプリを開き直して計測に戻ってきた。
        var isResumed = false
        var phase = Phase.running
        /// 計測を始めた日が終わる時刻。これを過ぎたぶんは、次の日の分として数える。
        var dayEnd = Date.distantFuture

        enum Phase: Equatable {
            case running
            case finished(Summary)
        }

        struct Summary: Equatable {
            var sessionSeconds: Int
            var reachedTarget: Bool
        }

        /// この計測で、あと何秒やれば今日の分に達するか。すでに達していれば 0。
        var remainingAtStart: Int { max(0, goal.dailySeconds - baseSeconds) }

        /// 今日の分に達する時刻。すでに達していれば nil(好きなだけ続ける計測になる)。
        var endsAt: Date? {
            guard remainingAtStart > 0 else { return nil }
            let target = startedAt.addingTimeInterval(Double(remainingAtStart))
            if target <= dayEnd { return target }
            // 達する前に日付が変わる。変わったあとは新しい日の分として数え直されるので、
            // そこから1日の量をやり終える時刻が目標になる。ロックの判定(LockEngine)と同じ数え方にそろえる。
            return dayEnd.addingTimeInterval(Double(goal.dailySeconds))
        }

        /// `end` で止めたとき、その時点の「今日の分」に達しているか。
        func reachesTarget(endingAt end: Date) -> Bool {
            if end > dayEnd {
                // 日付が変わったあとは、変わってからやった量だけで判定する。
                return Int(end.timeIntervalSince(dayEnd)) >= goal.dailySeconds
            }
            return baseSeconds + max(0, Int(end.timeIntervalSince(startedAt))) >= goal.dailySeconds
        }
    }

    enum Action {
        case task
        case targetReached
        case stopTapped
        case continueTapped
        case closeTapped
    }

    private enum CancelID { case target }

    /// これより短い計測は、押し間違いとして記録しない。
    static let minimumSeconds = 5
    /// 終わりのない計測(今日の分を終えたあとの延長)を、開き直したときに打ち切る長さ。
    /// 止め忘れて一晩たっても、記録が膨らまないようにする。
    static let openEndedCap: TimeInterval = 3 * 3600

    @Dependency(\.calendar) var calendar
    @Dependency(\.continuousClock) var clock
    @Dependency(\.database) var database
    @Dependency(\.date.now) var now
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.liveActivity) var liveActivity
    @Dependency(\.uuid) var uuid

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                guard state.phase == .running else { return .none }
                return start(&state)

            case .targetReached:
                guard state.phase == .running, let endsAt = state.endsAt else { return .none }
                // 開き直したときにすでに過ぎていても、達した時刻で止まったものとして扱う。
                return finish(&state, at: endsAt)

            case .stopTapped:
                guard state.phase == .running else { return .none }
                return finish(&state, at: now)

            case .continueTapped:
                // 止めたところから続ける。今日の分に届いていれば、終わりのない計測になる。
                // 保存した記録が共有の状態に届く前に押されても狂わないよう、いまの計測のぶんは手元で足す。
                var done = state.baseSeconds
                if case let .finished(summary) = state.phase, summary.sessionSeconds >= Self.minimumSeconds {
                    done += summary.sessionSeconds
                }
                let recorded = state.board.status.goals.first { $0.id == state.goal.id }?.recordedSeconds ?? 0
                state.baseSeconds = max(done, recorded)
                state.startedAt = now
                state.isResumed = false
                state.phase = .running
                return start(&state)

            case .closeTapped:
                return .run { _ in await dismiss() }
            }
        }
    }

    private func start(_ state: inout State) -> Effect<Action> {
        let focus = ActiveFocus(goalID: state.goal.id, startedAt: state.startedAt)
        let persist: Effect<Action> = state.isResumed
            ? .none
            : .run { [goal = state.goal, endsAt = state.endsAt] _ in
                try await database.setActiveFocus(focus)
                await liveActivity.start(goal, focus.startedAt, endsAt)
            }

        if let endsAt = state.endsAt {
            let delay = max(0, endsAt.timeIntervalSince(now))
            return .merge(
                persist,
                .run { send in
                    try await clock.sleep(for: .seconds(delay))
                    await send(.targetReached)
                }
                .cancellable(id: CancelID.target, cancelInFlight: true)
            )
        }
        // 終わりのない計測を開き直したとき、長すぎれば打ち切る。
        if state.isResumed, now.timeIntervalSince(state.startedAt) > Self.openEndedCap {
            return finish(&state, at: state.startedAt.addingTimeInterval(Self.openEndedCap))
        }
        return persist
    }

    private func finish(_ state: inout State, at end: Date) -> Effect<Action> {
        let seconds = max(0, Int(end.timeIntervalSince(state.startedAt)))
        state.phase = .finished(
            State.Summary(
                sessionSeconds: seconds,
                reachedTarget: state.reachesTarget(endingAt: end)
            )
        )
        // 1日の区切りをまたいだ計測は、区切りで分けて記録する。またいだあとのぶんを、今日の分として数えるため。
        let dayClock = DayClock(calendar: calendar, dayStartHour: state.board.world.preferences.dayStartHour)
        let sessions = seconds >= Self.minimumSeconds
            ? dayClock.split(from: state.startedAt, to: state.startedAt.addingTimeInterval(Double(seconds))).map {
                FocusSession(id: uuid(), goalID: state.goal.id, startedAt: $0.start, seconds: Int($0.duration))
            }
            : []
        return .merge(
            .cancel(id: CancelID.target),
            .run { _ in
                try await database.finishFocus(sessions)
                await liveActivity.end()
            }
        )
    }
}
