import ComposableArchitecture
import Domain
import Foundation
import ShieldClient
import Testing
@testable import AppFeature

@MainActor
@Suite("設定の画面")
struct SettingsFeatureTests {
    /// 10/9(金)14:00。
    let now = date(9, 14)
    let spy = DatabaseSpy()
    let dismissed = LockIsolated(0)
    /// 保存済みの設定。初期値と区別できるよう、いくつか変えてある。
    let saved = Preferences(dayStartHour: 5, buffer: .quarter, weeklyPassLimit: 3, hasCompletedOnboarding: true)

    /// スクリーンタイムの層へ伝えた指示。
    let applied = LockIsolated<[ShieldPlan]>([])

    private func makeStore(
        world: World? = nil,
        authorization: ShieldAuthorization = .approved,
        selectionCount: Int = 6
    ) -> TestStoreOf<SettingsFeature> {
        prepareBoard(world ?? World(preferences: saved), now: now)
        return TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.database = spy.client
            $0.countDismiss(into: dismissed)
            $0.shield.authorization = { authorization }
            $0.shield.requestAuthorization = { authorization }
            $0.shield.selectionCount = { selectionCount }
            $0.shield.apply = { [applied] plan, _ in applied.withValue { $0.append(plan) } }
        }
    }

    @Test("開いたときは、保存済みの設定を表示する")
    func loadsSavedPreferences() {
        let store = makeStore()
        #expect(store.state.preferences == saved)
    }

    @Test("パスの回数を変えると、すぐに保存する")
    func changingPassLimitPersists() async {
        let store = makeStore()

        await store.send(.binding(.set(\.preferences.weeklyPassLimit, 0))) {
            $0.preferences.weeklyPassLimit = 0
        }
        await store.finish()

        var expected = saved
        expected.weeklyPassLimit = 0
        #expect(spy.writes == [.savePreferences(expected)])
        #expect(dismissed.value == 0)
    }

    @Test("倍率と1日の区切りを続けて変えると、変えるたびにその時点の設定を保存する")
    func eachChangePersists() async {
        let store = makeStore()

        await store.send(.binding(.set(\.preferences.buffer, .double))) {
            $0.preferences.buffer = .double
        }
        await store.send(.binding(.set(\.preferences.dayStartHour, 0))) {
            $0.preferences.dayStartHour = 0
        }
        await store.finish()

        var first = saved
        first.buffer = .double
        var second = first
        second.dayStartHour = 0
        #expect(spy.writes == [.savePreferences(first), .savePreferences(second)])
    }

    @Test("同じ値を選び直しただけなら、保存しない")
    func unchangedValueIsNotSaved() async {
        let store = makeStore()

        await store.send(.binding(.set(\.preferences.weeklyPassLimit, 3)))
        await store.finish()

        #expect(spy.writes.isEmpty)
    }

    @Test("「はじめの説明をもう一度見る」を押すと、初回設定を未完了に戻して保存し、画面を閉じる")
    func replayOnboardingResetsFlag() async {
        let store = makeStore()

        await store.send(.replayOnboardingTapped) {
            $0.preferences.hasCompletedOnboarding = false
        }
        await store.finish()

        var expected = saved
        expected.hasCompletedOnboarding = false
        // ほかの設定は変えない。保存は 1 回だけ。
        #expect(spy.writes == [.savePreferences(expected)])
        #expect(dismissed.value == 1)
    }

    @Test("完了を押すと、画面を閉じる")
    func doneDismisses() async {
        let store = makeStore()

        await store.send(.doneTapped)
        await store.finish()

        #expect(spy.writes.isEmpty)
        #expect(dismissed.value == 1)
    }

    // MARK: ロックするアプリ

    @Test("開いたときに、ロックの許可の状態と、選んでいるアプリの数を読む")
    func taskLoadsShieldState() async {
        let store = makeStore(authorization: .approved, selectionCount: 4)

        await store.send(.task)
        await store.receive(\.shieldResponse) {
            $0.authorization = .approved
            $0.selectionCount = 4
        }
    }

    @Test("許可を求めて認められると、許可済みになり、選んだ数が入る")
    func allowRequestsAuthorization() async {
        let store = makeStore()

        await store.send(.allowTapped)
        await store.receive(\.shieldResponse) {
            $0.authorization = .approved
            $0.selectionCount = 6
        }
    }

    @Test("許可が認められなければ、認められなかった状態になる")
    func allowDenied() async {
        let store = makeStore(authorization: .denied, selectionCount: 0)

        await store.send(.allowTapped)
        await store.receive(\.shieldResponse) {
            $0.authorization = .denied
        }
    }

    @Test("アプリを選ぶボタンを押すと、選ぶ画面を出す")
    func chooseAppsPresentsPicker() async {
        let store = makeStore()

        await store.send(.chooseAppsTapped) {
            $0.isPickerPresented = true
        }
    }

    @Test("選び直すと、いまのロックの指示を伝え直し、選んだ数を読み直す")
    func selectionChangeReappliesShield() async {
        // 朝からロック中の目標がある。
        let world = World.exact(goals: [.fixture()])
        let store = makeStore(world: world, selectionCount: 9)

        await store.send(.selectionChanged)
        await store.receive(\.shieldResponse) {
            $0.authorization = .approved
            $0.selectionCount = 9
        }

        #expect(applied.value == [ShieldPlan(isLocked: true, title: "院試", remainingSeconds: 30 * 60)])
        // 設定そのものは変えていないので、保存はしない。
        #expect(spy.writes.isEmpty)
    }
}
