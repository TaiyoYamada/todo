import ComposableArchitecture
import DatabaseClient
import Domain
import Foundation

/// 設定の画面。
@Reducer
struct SettingsFeature {
    @ObservableState
    struct State: Equatable {
        @SharedReader(.board) var board
        var preferences: Preferences

        init() {
            preferences = Preferences()
            preferences = board.world.preferences
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case replayOnboardingTapped
        case doneTapped
    }

    @Dependency(\.database) var database
    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<Self> {
        BindingReducer()
            .onChange(of: \.preferences) { _, preferences in
                Reduce { _, _ in
                    .run { _ in try await database.savePreferences(preferences) }
                }
            }
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .replayOnboardingTapped:
                state.preferences.hasCompletedOnboarding = false
                return .run { [preferences = state.preferences] _ in
                    try await database.savePreferences(preferences)
                    await dismiss()
                }

            case .doneTapped:
                return .run { _ in await dismiss() }
            }
        }
    }
}
