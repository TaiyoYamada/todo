import ComposableArchitecture
import Domain
import Foundation
import ShieldClient
import Testing
@testable import AppFeature

@MainActor
@Suite("初回設定")
struct OnboardingFeatureTests {
    /// 10/9(金)14:00。
    let now = date(9, 14)
    let spy = DatabaseSpy()

    private func makeStore(
        _ state: OnboardingFeature.State? = nil,
        world: World = World(),
        authorization: ShieldAuthorization = .approved,
        selectionCount: Int = 6
    ) -> TestStoreOf<OnboardingFeature> {
        prepareBoard(world, now: now)
        return TestStore(initialState: state ?? OnboardingFeature.State()) {
            OnboardingFeature()
        } withDependencies: {
            $0.fix(now: LockIsolated(now), database: spy)
            $0.shield.requestAuthorization = { authorization }
            $0.shield.selectionCount = { selectionCount }
        }
    }

    private func state(at step: OnboardingFeature.Step, title: String = "") -> OnboardingFeature.State {
        var state = OnboardingFeature.State()
        state.step = step
        state.goalTitle = title
        return state
    }

    // MARK: 段階の移動

    @Test("「次へ」で、導入 → 仕組み → 目標 → アプリ → 準備完了 の順に進む")
    func nextAdvancesThroughSteps() async {
        let store = makeStore()

        await store.send(.nextTapped) {
            $0.step = .mechanism
        }
        await store.send(.nextTapped) {
            $0.step = .goal
        }
        await store.send(.binding(.set(\.goalTitle, "院試"))) {
            $0.goalTitle = "院試"
        }
        await store.send(.nextTapped) {
            $0.step = .apps
        }
        await store.send(.nextTapped) {
            $0.step = .ready
        }
        // 最後の段階より先には進まない。
        await store.send(.nextTapped)
    }

    @Test("目標の段階では、名前を入れるまで先へ進めない")
    func goalStepRequiresTitle() async {
        let store = makeStore(state(at: .goal))
        #expect(!store.state.canAdvance)

        await store.send(.nextTapped)

        // 空白だけでも進めない。
        await store.send(.binding(.set(\.goalTitle, "  \n"))) {
            $0.goalTitle = "  \n"
        }
        #expect(!store.state.canAdvance)
        await store.send(.nextTapped)

        await store.send(.binding(.set(\.goalTitle, " 院試 "))) {
            $0.goalTitle = " 院試 "
        }
        #expect(store.state.canAdvance)
        await store.send(.nextTapped) {
            $0.step = .apps
        }
    }

    @Test("名前の入力を求めるのは、目標の段階だけ")
    func otherStepsDoNotRequireTitle() {
        prepareBoard(World(), now: now)
        for step in OnboardingFeature.Step.allCases where step != .goal {
            #expect(state(at: step).canAdvance, "\(step)")
        }
    }

    @Test("「戻る」で1つ前の段階に戻り、最初の段階より前には戻らない")
    func backReturnsToPreviousStep() async {
        let store = makeStore(state(at: .goal, title: "院試"))

        await store.send(.backTapped) {
            $0.step = .mechanism
        }
        await store.send(.backTapped) {
            $0.step = .hook
        }
        await store.send(.backTapped)
    }

    @Test("1日の量の選択肢を押すと、その量が選ばれる")
    func minutesSelects() async {
        let store = makeStore(state(at: .goal))

        await store.send(.minutesTapped(45)) {
            $0.goalMinutes = 45
        }
    }

    // MARK: ロックの許可

    @Test("許可を求めて認められると、許可済みになり、選んだ数が入る")
    func authorizationApproved() async {
        let store = makeStore(state(at: .apps, title: "院試"))

        await store.send(.allowTapped) {
            $0.isRequestingAuthorization = true
        }
        await store.receive(\.authorizationResponse) {
            $0.isRequestingAuthorization = false
            $0.authorization = .approved
            $0.selectionCount = 6
        }
    }

    @Test("許可が認められなくても、求めている最中の状態は解ける")
    func authorizationDenied() async {
        let store = makeStore(state(at: .apps, title: "院試"), authorization: .denied, selectionCount: 0)

        await store.send(.allowTapped) {
            $0.isRequestingAuthorization = true
        }
        await store.receive(\.authorizationResponse) {
            $0.isRequestingAuthorization = false
            $0.authorization = .denied
        }
        // 許可がなくても、あとで設定することにして先へ進める。
        await store.send(.nextTapped) {
            $0.step = .ready
        }
    }

    // MARK: 終える

    @Test("終えると、最初の目標を作り、初回設定を済ませたことを保存する")
    func finishSavesGoalAndFlag() async {
        var initial = state(at: .ready, title: "  院試 ")
        initial.goalMinutes = 45
        let store = makeStore(initial)

        await store.send(.finishTapped)
        await store.receive(\.delegate, .finished)
        await store.finish()

        #expect(
            spy.writes == [
                // 名前は前後の空白を除く。ほかは目標の初期値(毎日、朝からロック)。
                .saveGoal(Goal(id: uuid(0), title: "院試", dailyMinutes: 45, createdAt: now)),
                .savePreferences(Preferences(hasCompletedOnboarding: true)),
            ]
        )
    }

    @Test("名前を入れずに終えると、目標は作らず、初回設定を済ませたことだけを保存する")
    func finishWithoutTitleSavesOnlyFlag() async {
        let store = makeStore(state(at: .ready))

        await store.send(.finishTapped)
        await store.receive(\.delegate, .finished)
        await store.finish()

        #expect(spy.writes == [.savePreferences(Preferences(hasCompletedOnboarding: true))])
    }

    @Test("やり直しで終えても、ほかの設定はそのまま残す")
    func finishKeepsOtherPreferences() async {
        // 設定から「はじめの説明をもう一度見る」を選んだあとの状態。
        let saved = Preferences(dayStartHour: 6, buffer: .half, weeklyPassLimit: 4, hasCompletedOnboarding: false)
        let store = makeStore(state(at: .ready), world: World(goals: [.fixture()], preferences: saved))

        await store.send(.finishTapped)
        await store.receive(\.delegate, .finished)
        await store.finish()

        var expected = saved
        expected.hasCompletedOnboarding = true
        #expect(spy.writes == [.savePreferences(expected)])
    }
}
