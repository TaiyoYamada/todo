import ComposableArchitecture
import SwiftUI

struct OnboardingView: View {
    let store: StoreOf<OnboardingFeature>

    var body: some View {
        Button {
            store.send(.finishTapped)
        } label: {
            Text(.commonDone)
        }
    }
}
