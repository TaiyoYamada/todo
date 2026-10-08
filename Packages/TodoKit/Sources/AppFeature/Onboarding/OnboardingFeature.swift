import ComposableArchitecture
import DatabaseClient
import Domain
import Foundation
import ShieldClient

/// 初回設定。仕組みを伝え、最初の目標を1つ作り、ロックの許可をもらう。
@Reducer
struct OnboardingFeature {
    enum Step: Int, CaseIterable, Sendable {
        case hook, mechanism, goal, apps, ready
    }

    @ObservableState
    struct State: Equatable {
        @SharedReader(.board) var board
        var step = Step.hook
        var goalTitle = ""
        var goalMinutes = 30
        var authorization = ShieldAuthorization.notDetermined
        var selectionCount = 0
        var isRequestingAuthorization = false
        var isPickerPresented = false

        var trimmedTitle: String { goalTitle.trimmingCharacters(in: .whitespacesAndNewlines) }

        /// いまの段階から先へ進めるか。目標の段階だけ、名前の入力を求める。
        var canAdvance: Bool { step != .goal || !trimmedTitle.isEmpty }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case nextTapped
        case backTapped
        case minutesTapped(Int)
        case allowTapped
        case chooseAppsTapped
        case selectionChanged
        case authorizationResponse(ShieldAuthorization, selectionCount: Int)
        case finishTapped
        case delegate(Delegate)

        enum Delegate: Equatable {
            case finished
        }
    }

    static let minutesPresets = [15, 30, 45, 60]

    @Dependency(\.database) var database
    @Dependency(\.date.now) var now
    @Dependency(\.shield) var shield
    @Dependency(\.uuid) var uuid

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding, .delegate:
                return .none

            case .nextTapped:
                guard state.canAdvance, let next = Step(rawValue: state.step.rawValue + 1) else { return .none }
                state.step = next
                return .none

            case .backTapped:
                guard let previous = Step(rawValue: state.step.rawValue - 1) else { return .none }
                state.step = previous
                return .none

            case let .minutesTapped(minutes):
                state.goalMinutes = minutes
                return .none

            case .allowTapped:
                state.isRequestingAuthorization = true
                return .run { send in
                    let authorization = await shield.requestAuthorization()
                    await send(.authorizationResponse(authorization, selectionCount: shield.selectionCount()))
                }

            case .chooseAppsTapped:
                state.isPickerPresented = true
                return .none

            case .selectionChanged:
                return .run { send in
                    await send(.authorizationResponse(shield.authorization(), selectionCount: shield.selectionCount()))
                }

            case let .authorizationResponse(authorization, selectionCount):
                state.isRequestingAuthorization = false
                state.authorization = authorization
                state.selectionCount = selectionCount
                return .none

            case .finishTapped:
                var preferences = state.board.world.preferences
                preferences.hasCompletedOnboarding = true
                // やり直しのときなど、名前を入れずに進んだ場合は目標を作らない。
                let goal = state.trimmedTitle.isEmpty
                    ? nil
                    : Goal(id: uuid(), title: state.trimmedTitle, dailyMinutes: state.goalMinutes, createdAt: now)
                return .run { [preferences] send in
                    if let goal {
                        try await database.saveGoal(goal)
                    }
                    try await database.savePreferences(preferences)
                    await send(.delegate(.finished))
                }
            }
        }
    }
}
