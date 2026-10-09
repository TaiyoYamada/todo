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
                Playful.background.ignoresSafeArea()
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
        .tint(Playful.mint.face)
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

    /// 画面と、その下のタブ。
    ///
    /// OS 標準のタブバーは半透明のガラスになるので使わず、単色のものを自前で置く。
    private var tabs: some View {
        VStack(spacing: 0) {
            Group {
                switch store.selectedTab {
                case .today:
                    TodayView(store: store.scope(state: \.today, action: \.today))
                case .plan:
                    PlanView(store: store.scope(state: \.plan, action: \.plan))
                case .insights:
                    InsightsView(store: store.scope(state: \.insights, action: \.insights))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            TabBar(selection: $store.selectedTab)
        }
        .background(Playful.background.ignoresSafeArea())
    }
}

/// 下のタブ。選んだものだけ、太い枠で囲んで色を付ける。
private struct TabBar: View {
    @Binding var selection: AppFeature.Tab

    private struct Item {
        let tab: AppFeature.Tab
        let title: LocalizedStringResource
        let symbol: String
        let identifier: String
    }

    private let items = [
        Item(tab: .today, title: .tabToday, symbol: "lock.fill", identifier: "tab.today"),
        Item(tab: .plan, title: .tabPlan, symbol: "checklist", identifier: "tab.plan"),
        Item(tab: .insights, title: .tabInsights, symbol: "chart.bar.fill", identifier: "tab.insights"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Playful.line)
                .frame(height: 2)
            HStack(spacing: 8) {
                ForEach(items, id: \.identifier) { item in
                    button(item)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
        .background(Playful.background)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func button(_ item: Item) -> some View {
        let isSelected = item.tab == selection
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Button {
            selection = item.tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: item.symbol)
                    .font(.title3.weight(.bold))
                    .symbolEffect(.bounce, value: isSelected)
                    .accessibilityHidden(true)
                Text(item.title)
                    .font(.system(.caption2, design: .rounded, weight: .heavy))
            }
            .foregroundStyle(isSelected ? Playful.mint.face : Playful.subtext)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(isSelected ? Playful.mint.face.opacity(0.14) : .clear, in: shape)
            .overlay { shape.strokeBorder(isSelected ? Playful.mint.face : .clear, lineWidth: 2) }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(item.identifier)
        .animation(.spring(duration: 0.3, bounce: 0.4), value: isSelected)
    }
}
