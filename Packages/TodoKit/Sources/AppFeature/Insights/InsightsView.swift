import Charts
import ComposableArchitecture
import DesignSystem
import Domain
import SwiftUI

struct InsightsView: View {
    let store: StoreOf<InsightsFeature>
    @Dependency(\.calendar) private var calendar
    private let tone = Playful.mint

    var body: some View {
        let world = store.board.world
        let insights = InsightsCalculator(calendar: calendar).insights(world: world, now: store.board.status.now)

        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    WeekSummary(insights: insights)
                    if insights.hasAnyFocus {
                        FocusChart(insights: insights, goals: world.goals)
                    }
                    CalibrationCard(calibration: insights.calibration, factor: world.estimateFactor)
                    TasksSummary(insights: insights, passLimit: world.preferences.weeklyPassLimit)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(Playful.background.ignoresSafeArea())
            .navigationTitle(Text(.tabInsights))
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .environment(\.tone, tone)
        .foregroundStyle(Playful.text)
    }
}

// MARK: - 今週の合計

private struct WeekSummary: View {
    let insights: Insights
    @Environment(\.tone) private var tone

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(.insightsWeekTitle)
                .accessibilityIdentifier("insights.week.title")
                .chunkyHeading()
            Text(DurationText.compact(minutes: insights.thisWeekSeconds / 60))
                .font(.hero(52))
                .monospacedDigit()
                .contentTransition(.numericText())
            comparison
                .font(.subheadline.weight(.semibold))
        }
        .chunkyCard()
    }

    @ViewBuilder
    private var comparison: some View {
        let difference = (insights.thisWeekSeconds - insights.lastWeekSeconds) / 60
        if insights.lastWeekSeconds == 0, insights.thisWeekSeconds == 0 {
            Text(.insightsWeekEmpty)
                .foregroundStyle(Playful.subtext)
        } else if difference >= 0 {
            Label {
                Text(.insightsWeekMore(DurationText.compact(minutes: max(1, difference))))
            } icon: {
                Image(systemName: "arrow.up.right")
            }
            .foregroundStyle(tone.face)
        } else {
            Label {
                Text(.insightsWeekLess(DurationText.compact(minutes: -difference)))
            } icon: {
                Image(systemName: "arrow.down.right")
            }
            .foregroundStyle(Playful.subtext)
        }
    }
}

// MARK: - 日ごとの推移

private struct FocusChart: View {
    let insights: Insights
    let goals: [Goal]

    private struct Bar: Identifiable {
        let id: String
        let day: Date
        let goal: Goal
        let minutes: Int
    }

    private var bars: [Bar] {
        insights.days.flatMap { day in
            day.segments.compactMap { segment in
                goals.first { $0.id == segment.goalID }.map { goal in
                    Bar(
                        id: "\(day.dayStart.timeIntervalSince1970)-\(goal.id)",
                        day: day.dayStart,
                        goal: goal,
                        minutes: segment.seconds / 60
                    )
                }
            }
        }
    }

    var body: some View {
        let shownGoals = goals.filter { goal in bars.contains { $0.goal.id == goal.id } }
        VStack(alignment: .leading, spacing: 14) {
            Text(.insightsChartTitle)
                .accessibilityIdentifier("insights.chart.title")
                .chunkyHeading()
            Chart(bars) { bar in
                BarMark(
                    // 軸の名前は VoiceOver のグラフの読み上げに使われる。文字列のまま渡すと、
                    // Xcode が訳のないキーとして文言カタログに足してしまうので、カタログの文言を渡す。
                    x: .value(Text(.insightsChartAxisDay), bar.day, unit: .day),
                    y: .value(Text(.insightsChartAxisMinutes), bar.minutes),
                    width: .ratio(0.62)
                )
                .foregroundStyle(by: .value(Text(.insightsChartAxisGoal), bar.goal.title))
                .clipShape(.rect(cornerRadius: 4))
            }
            .chartForegroundStyleScale(
                domain: shownGoals.map(\.title),
                range: shownGoals.map(\.tint.color)
            )
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                    AxisValueLabel(format: .dateTime.day(), centered: true)
                        .foregroundStyle(Playful.subtext)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine().foregroundStyle(Playful.subtext)
                    AxisValueLabel {
                        if let minutes = value.as(Int.self) {
                            Text(DurationText.compact(minutes: minutes))
                                .foregroundStyle(Playful.subtext)
                        }
                    }
                }
            }
            .chartLegend(position: .bottom, alignment: .leading)
            .frame(height: 210)
        }
        .chunkyCard()
    }
}

// MARK: - 見積もりの癖

private struct CalibrationCard: View {
    let calibration: EstimateCalibration
    let factor: Double
    @Environment(\.tone) private var tone

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(.insightsCalibrationTitle)
                .accessibilityIdentifier("insights.calibration.title")
                .chunkyHeading()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: "×")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(Playful.subtext)
                Text(factor, format: .number.precision(.fractionLength(0 ... 2)))
                    .font(.hero(52))
                    .monospacedDigit()
                    .foregroundStyle(tone.face)
            }
            Text(explanation)
                .font(.subheadline)
                .foregroundStyle(Playful.subtext)
        }
        .chunkyCard()
    }

    private var explanation: LocalizedStringResource {
        if calibration.isLearned {
            .insightsCalibrationLearned(calibration.sampleCount)
        } else {
            .insightsCalibrationLearning(EstimateCalibration.minimumSamples - calibration.sampleCount)
        }
    }
}

// MARK: - タスクとパス

private struct TasksSummary: View {
    let insights: Insights
    let passLimit: Int
    @Environment(\.tone) private var tone

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(.insightsTasksTitle)
                .accessibilityIdentifier("insights.tasks.title")
                .chunkyHeading()
            HStack(alignment: .top, spacing: 10) {
                stat(insights.tasksBeforeLimit, .insightsTasksBeforeLimit, color: tone.face)
                stat(insights.tasksAfterLimit, .insightsTasksAfterLimit, color: Playful.amber.face)
                stat(insights.tasksWithdrawn, .insightsTasksWithdrawn, color: Playful.subtext)
            }
            Rectangle().fill(Playful.line).frame(height: 2)
            LabeledContent {
                Text(.insightsPassesValue(insights.passesThisWeek, passLimit))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
            } label: {
                Label { Text(.insightsPassesLabel) } icon: { Image(systemName: "hourglass") }
            }
            .foregroundStyle(Playful.text)
        }
        .chunkyCard()
    }

    private func stat(_ value: Int, _ title: LocalizedStringResource, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value, format: .number)
                .font(.hero(34))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Playful.subtext)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
