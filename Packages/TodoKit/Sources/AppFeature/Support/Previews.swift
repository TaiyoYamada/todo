import ComposableArchitecture
import Domain
import SwiftUI

// Xcode のプレビュー。見本データの各状態で、主要な画面をすぐ確認できるようにまとめてある。
// 画面ごとのファイルに散らさないのは、状態の用意(共有の Board への書き込み)を1か所にするため。

/// 見本データを共有の状況(Board)に入れてから、中身を表示する。
private struct SamplePreview<Content: View>: View {
    private let content: Content

    init(_ scenario: SampleData.Scenario, @ViewBuilder content: () -> Content) {
        @Shared(.board) var board
        let world = SampleData.world(scenario)
        $board.withLock {
            $0 = Board(
                world: world,
                status: LockEngine(calendar: .current).status(world: world, now: .now),
                isLoaded: true
            )
        }
        self.content = content()
    }

    var body: some View {
        content.preferredColorScheme(.dark)
    }
}

#Preview("今日: ロック中") {
    SamplePreview(.locked) {
        TodayView(store: Store(initialState: TodayFeature.State()) { TodayFeature() })
    }
}

#Preview("今日: 次のロックまで") {
    SamplePreview(.countdown) {
        TodayView(store: Store(initialState: TodayFeature.State()) { TodayFeature() })
    }
}

#Preview("今日: 自由") {
    SamplePreview(.free) {
        TodayView(store: Store(initialState: TodayFeature.State()) { TodayFeature() })
    }
}

#Preview("今日: 何もない") {
    SamplePreview(.fresh) {
        TodayView(store: Store(initialState: TodayFeature.State()) { TodayFeature() })
    }
}

#Preview("集中: 計測中") {
    SamplePreview(.locked) {
        let goal = SampleData.world(.locked).goals[0]
        FocusView(
            store: Store(
                initialState: FocusFeature.State(goal: goal, startedAt: .now, baseSeconds: 20 * 60)
            ) {
                FocusFeature()
            }
        )
    }
}

#Preview("集中: 今日の分を完了") {
    SamplePreview(.free) {
        let goal = SampleData.world(.free).goals[0]
        var state = FocusFeature.State(goal: goal, startedAt: .now, baseSeconds: 0)
        state.phase = .finished(.init(sessionSeconds: goal.dailySeconds, reachedTarget: true))
        return FocusView(store: Store(initialState: state) { EmptyReducer() })
    }
}

#Preview("予定") {
    SamplePreview(.countdown) {
        PlanView(store: Store(initialState: PlanFeature.State()) { PlanFeature() })
    }
}

#Preview("振り返り") {
    SamplePreview(.countdown) {
        InsightsView(store: Store(initialState: InsightsFeature.State()) { InsightsFeature() })
    }
}

#Preview("設定") {
    SamplePreview(.countdown) {
        SettingsView(store: Store(initialState: SettingsFeature.State()) { SettingsFeature() })
    }
}

#Preview("初回設定") {
    SamplePreview(.fresh) {
        OnboardingView(store: Store(initialState: OnboardingFeature.State()) { OnboardingFeature() })
    }
}

#Preview("目標の追加") {
    GoalEditorView(
        store: Store(
            initialState: GoalEditorFeature.State(goal: Goal(id: UUID(), title: "", createdAt: .now), isNew: true)
        ) {
            GoalEditorFeature()
        }
    )
    .preferredColorScheme(.dark)
}

#Preview("タスクの追加") {
    SamplePreview(.countdown) {
        TaskEditorView(
            store: Store(
                initialState: TaskEditorFeature.State(
                    task: TaskItem(id: UUID(), title: "", dueAt: .now.addingTimeInterval(86400), createdAt: .now),
                    isNew: true
                )
            ) {
                TaskEditorFeature()
            }
        )
    }
}

#Preview("タスクの完了") {
    let task = SampleData.world(.locked).tasks[0]
    return Color.black
        .sheet(isPresented: .constant(true)) {
            TaskCompletionView(
                store: Store(initialState: TaskCompletionFeature.State(task: task)) { TaskCompletionFeature() }
            )
        }
        .preferredColorScheme(.dark)
}
