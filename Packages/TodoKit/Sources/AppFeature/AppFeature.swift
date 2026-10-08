import ComposableArchitecture
import SwiftUI

@Reducer
public struct AppFeature {
    @ObservableState
    public struct State: Equatable {
        public init() {}
    }

    public enum Action {
        case onAppear
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .onAppear:
                .none
            }
        }
    }
}

public struct AppView: View {
    let store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        Text(.todayTitle)
            .onAppear { store.send(.onAppear) }
    }
}
