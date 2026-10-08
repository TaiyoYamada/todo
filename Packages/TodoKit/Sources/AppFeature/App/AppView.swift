import ComposableArchitecture
import DatabaseClient
import DesignSystem
import SwiftUI

/// アプリの入口。アプリ本体からは、この View だけが見える。
public struct RootView: View {
    @State private var store: StoreOf<AppFeature>

    /// - Parameter sampleScenario: 見本データの状態の名前(`locked` など)。指定すると、
    ///   保存データの代わりにメモリ上の見本データで動く。開発用の構成でだけ渡す。
    public init(sampleScenario: String? = nil) {
        let scenario = sampleScenario.flatMap(SampleData.Scenario.init(rawValue:))
        _store = State(
            initialValue: Store(initialState: AppFeature.State()) {
                AppFeature()
            } withDependencies: {
                if let scenario {
                    $0.database = .inMemory(SampleData.world(scenario))
                }
            }
        )
    }

    public var body: some View {
        AppView(store: store)
    }
}

struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if !store.board.isLoaded {
                // 保存データを読み終えるまでの一瞬。背景だけを出して、画面のちらつきを防ぐ。
                AuroraBackground(mood: .calm)
            } else if let onboarding = store.scope(state: \.onboarding, action: \.onboarding) {
                OnboardingView(store: onboarding)
                    .transition(.opacity)
            } else {
                tabs
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.5), value: store.onboarding == nil)
        .preferredColorScheme(.dark)
        .tint(Mood.calm.accent)
        .task { await store.send(.task).finish() }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                store.send(.becameActive)
            }
        }
        .fullScreenCover(item: $store.scope(state: \.destination?.focus, action: \.destination.focus)) { store in
            FocusView(store: store)
        }
        .sheet(item: $store.scope(state: \.destination?.goalEditor, action: \.destination.goalEditor)) { store in
            GoalEditorView(store: store)
        }
        .sheet(item: $store.scope(state: \.destination?.taskEditor, action: \.destination.taskEditor)) { store in
            TaskEditorView(store: store)
        }
        .sheet(
            item: $store.scope(state: \.destination?.taskCompletion, action: \.destination.taskCompletion)
        ) { store in
            TaskCompletionView(store: store)
        }
        .sheet(item: $store.scope(state: \.destination?.settings, action: \.destination.settings)) { store in
            SettingsView(store: store)
        }
    }

    private var tabs: some View {
        TabView(selection: $store.selectedTab) {
            Tab(value: AppFeature.Tab.today) {
                TodayView(store: store.scope(state: \.today, action: \.today))
            } label: {
                Label { Text(.tabToday) } icon: { Image(systemName: "timer") }
            }
            Tab(value: AppFeature.Tab.plan) {
                PlanView(store: store.scope(state: \.plan, action: \.plan))
            } label: {
                Label { Text(.tabPlan) } icon: { Image(systemName: "list.bullet.rectangle.portrait") }
            }
            Tab(value: AppFeature.Tab.insights) {
                InsightsView(store: store.scope(state: \.insights, action: \.insights))
            } label: {
                Label { Text(.tabInsights) } icon: { Image(systemName: "chart.bar.xaxis") }
            }
        }
    }
}
