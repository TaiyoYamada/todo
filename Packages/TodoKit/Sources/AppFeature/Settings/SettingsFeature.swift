import ComposableArchitecture
import DatabaseClient
import Domain
import Foundation
import ShieldClient

/// 設定の画面。
@Reducer
struct SettingsFeature {
    @ObservableState
    struct State: Equatable {
        @SharedReader(.board) var board
        var preferences: Preferences
        var authorization = ShieldAuthorization.notDetermined
        var selectionCount = 0
        var isPickerPresented = false

        init() {
            preferences = Preferences()
            preferences = board.world.preferences
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case task
        case allowTapped
        case chooseAppsTapped
        case selectionChanged
        case shieldResponse(ShieldAuthorization, selectionCount: Int)
        case replayOnboardingTapped
        case doneTapped
    }

    @Dependency(\.database) var database
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.shield) var shield

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

            case .task:
                return .run { send in
                    await send(.shieldResponse(shield.authorization(), selectionCount: shield.selectionCount()))
                }

            case .allowTapped:
                return .run { send in
                    let authorization = await shield.requestAuthorization()
                    await send(.shieldResponse(authorization, selectionCount: shield.selectionCount()))
                }

            case .chooseAppsTapped:
                state.isPickerPresented = true
                return .none

            case .selectionChanged:
                // 選び直した内容を、いま掛かっているロックにもすぐ反映する。
                let plan = ShieldPlan(status: state.board.status)
                return .run { [world = state.board.world] send in
                    await shield.apply(plan, world)
                    await send(.shieldResponse(shield.authorization(), selectionCount: shield.selectionCount()))
                }

            case let .shieldResponse(authorization, selectionCount):
                state.authorization = authorization
                state.selectionCount = selectionCount
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
