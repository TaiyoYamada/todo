import ComposableArchitecture
import DatabaseClient
import Domain
import Foundation

/// 初回設定。
@Reducer
struct OnboardingFeature {
    @ObservableState
    struct State: Equatable {
        @SharedReader(.board) var board
    }

    enum Action {
        case finishTapped
        case delegate(Delegate)

        enum Delegate: Equatable {
            case finished
        }
    }

    @Dependency(\.database) var database

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .finishTapped:
                var preferences = state.board.world.preferences
                preferences.hasCompletedOnboarding = true
                return .run { [preferences] send in
                    try await database.savePreferences(preferences)
                    await send(.delegate(.finished))
                }

            case .delegate:
                return .none
            }
        }
    }
}
