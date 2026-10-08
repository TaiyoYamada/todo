import ComposableArchitecture
import DatabaseClient
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
            $0.shield.authorization = { authorization }
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

    @Test("アプリを選ぶボタンを押すと、選ぶ画面を出す")
    func chooseAppsPresentsPicker() async {
        var initial = state(at: .apps, title: "院試")
        initial.authorization = .approved
        let store = makeStore(initial)

        await store.send(.chooseAppsTapped) {
            $0.isPickerPresented = true
        }
    }

    @Test("選ぶ画面で選び直すと、選んだ数を読み直す")
    func selectionChangeReloadsCount() async {
        var initial = state(at: .apps, title: "院試")
        initial.authorization = .approved
        initial.selectionCount = 2
        let store = makeStore(initial, selectionCount: 9)

        await store.send(.selectionChanged)
        await store.receive(\.authorizationResponse) {
            $0.selectionCount = 9
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
                // 済ませた印を先に保存する(順番の理由は次のテスト)。
                .savePreferences(Preferences(hasCompletedOnboarding: true)),
                // 名前は前後の空白を除く。ほかは目標の初期値(毎日、朝からロック)。
                .saveGoal(Goal(id: uuid(0), title: "院試", dailyMinutes: 45, createdAt: now)),
            ]
        )
    }

    @Test("終えるときに流れる保存データには、目標だけが増えて印がまだ、という途中の状態が現れない")
    func finishNeverPublishesGoalWithoutFlag() async {
        // 親は「印が付いていない保存データ」を、初回設定のやり直しの依頼として扱う。
        // 途中の状態が終了の知らせより遅れて届くと、終えた直後に最初の画面へ戻されてしまう。
        let database = DatabaseClient.inMemory(World())
        var worlds = database.observeWorld().makeAsyncIterator()
        #expect(await worlds.next() == World())

        prepareBoard(World(), now: now)
        let store = TestStore(initialState: state(at: .ready, title: "院試")) {
            OnboardingFeature()
        } withDependencies: {
            $0.fix(now: LockIsolated(now), database: spy)
            $0.database = database
        }
        await store.send(.finishTapped)
        await store.receive(\.delegate, .finished)
        await store.finish()

        let first = await worlds.next()
        #expect(first?.preferences.hasCompletedOnboarding == true)
        #expect(first?.goals.isEmpty == true)
        let second = await worlds.next()
        #expect(second?.preferences.hasCompletedOnboarding == true)
        #expect(second?.goals.map(\.title) == ["院試"])
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
