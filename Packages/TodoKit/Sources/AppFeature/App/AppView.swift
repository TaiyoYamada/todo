import ComposableArchitecture
import DatabaseClient
import DesignSystem
import SharedCore
import SwiftUI

/// アプリの入口。アプリ本体からは、この View だけが見える。
public struct RootView: View {
    @State private var store: StoreOf<AppFeature>

    /// - Parameters:
    ///   - sampleScenario: 見本データの状態の名前(`locked` など)。指定すると、
    ///     保存データの代わりにメモリ上の見本データで動く。開発用の構成でだけ渡す。
    ///   - initialTab: 最初に開くタブの名前(`plan`、`insights`)。画面の撮影用。
    public init(sampleScenario: String? = nil, initialTab: String? = nil) {
        let scenario = sampleScenario.flatMap(SampleData.Scenario.init(rawValue:))
        var state = AppFeature.State()
        switch initialTab {
        case "plan": state.selectedTab = .plan
        case "insights": state.selectedTab = .insights
        default: break
        }
        _store = State(
            initialValue: Store(initialState: state) {
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
        .onOpenURL { url in
            if let link = DeepLink(url: url) {
                store.send(.openDeepLink(link))
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                store.send(.becameActive)
            }
        }
        .task(id: scenePhase) {
            // コントロールセンターのボタンから開かれたときは、行き先が共有の置き場に書かれている。
            // ボタンの処理と、アプリが前面に来るのと、どちらが先かは決まっていないので、少しの間くり返し確かめる。
            guard scenePhase == .active else { return }
            for _ in 0 ..< 8 {
                if let link = PendingDeepLink.take() {
                    store.send(.openDeepLink(link))
                    return
                }
                try? await Task.sleep(for: .milliseconds(250))
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
