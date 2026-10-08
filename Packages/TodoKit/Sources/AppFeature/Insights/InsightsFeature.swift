import ComposableArchitecture
import Domain
import Foundation

/// 「振り返り」の画面。
@Reducer
struct InsightsFeature {
    @ObservableState
    struct State: Equatable {
        @SharedReader(.board) var board
    }

    enum Action {}

    var body: some ReducerOf<Self> {
        EmptyReducer()
    }
}
