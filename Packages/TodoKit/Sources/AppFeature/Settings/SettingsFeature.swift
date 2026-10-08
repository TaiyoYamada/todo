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
    }

    enum Action {
        case doneTapped
    }

    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .doneTapped:
                .run { _ in await dismiss() }
            }
        }
    }
}
