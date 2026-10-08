import Charts
import ComposableArchitecture
import DesignSystem
import Domain
import SwiftUI

struct InsightsView: View {
    let store: StoreOf<InsightsFeature>
    @Dependency(\.calendar) private var calendar
    private let mood = Mood.calm

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
            .background { AuroraBackground(mood: mood) }
            .navigationTitle(Text(.tabInsights))
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .environment(\.mood, mood)
        .foregroundStyle(.white)
    }
}

// MARK: - 今週の合計

private struct WeekSummary: View {
    let insights: Insights
    @Environment(\.mood) private var mood

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(.insightsWeekTitle)
                .accessibilityIdentifier("insights.week.title")
                .sectionLabelStyle()
            Text(DurationText.compact(minutes: insights.thisWeekSeconds / 60))
                .font(.system(size: 52, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            comparison
                .font(.subheadline.weight(.semibold))
        }
        .glassCard()
    }

    @ViewBuilder
    private var comparison: some View {
        let difference = (insights.thisWeekSeconds - insights.lastWeekSeconds) / 60
        if insights.lastWeekSeconds == 0, insights.thisWeekSeconds == 0 {
            Text(.insightsWeekEmpty)
                .foregroundStyle(.white.opacity(0.65))
        } else if difference >= 0 {
            Label {
                Text(.insightsWeekMore(DurationText.compact(minutes: max(1, difference))))
            } icon: {
                Image(systemName: "arrow.up.right")
            }
            .foregroundStyle(mood.accent)
        } else {
            Label {
                Text(.insightsWeekLess(DurationText.compact(minutes: -difference)))
            } icon: {
                Image(systemName: "arrow.down.right")
            }
            .foregroundStyle(.white.opacity(0.65))
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
                .sectionLabelStyle()
            Chart(bars) { bar in
                BarMark(
                    x: .value("day", bar.day, unit: .day),
                    y: .value("minutes", bar.minutes),
                    width: .ratio(0.62)
                )
                .foregroundStyle(by: .value("goal", bar.goal.title))
                .clipShape(.rect(cornerRadius: 4))
            }
            .chartForegroundStyleScale(
                domain: shownGoals.map(\.title),
                range: shownGoals.map(\.tint.color)
            )
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                    AxisValueLabel(format: .dateTime.day(), centered: true)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine().foregroundStyle(.white.opacity(0.12))
                    AxisValueLabel {
                        if let minutes = value.as(Int.self) {
                            Text(DurationText.compact(minutes: minutes))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
            }
            .chartLegend(position: .bottom, alignment: .leading)
            .frame(height: 210)
        }
        .glassCard()
    }
}

// MARK: - 見積もりの癖

private struct CalibrationCard: View {
    let calibration: EstimateCalibration
    let factor: Double
    @Environment(\.mood) private var mood

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(.insightsCalibrationTitle)
                .accessibilityIdentifier("insights.calibration.title")
                .sectionLabelStyle()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: "×")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                Text(factor, format: .number.precision(.fractionLength(0 ... 2)))
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(mood.accent)
            }
            Text(explanation)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
        }
        .glassCard()
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
    @Environment(\.mood) private var mood

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(.insightsTasksTitle)
                .accessibilityIdentifier("insights.tasks.title")
                .sectionLabelStyle()
            HStack(alignment: .top, spacing: 10) {
                stat(insights.tasksBeforeLimit, .insightsTasksBeforeLimit, color: mood.accent)
                stat(insights.tasksAfterLimit, .insightsTasksAfterLimit, color: Mood.warning.accent)
                stat(insights.tasksWithdrawn, .insightsTasksWithdrawn, color: .white.opacity(0.7))
            }
            Divider().overlay(.white.opacity(0.15))
            LabeledContent {
                Text(.insightsPassesValue(insights.passesThisWeek, passLimit))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
            } label: {
                Label { Text(.insightsPassesLabel) } icon: { Image(systemName: "hourglass") }
            }
            .foregroundStyle(.white.opacity(0.85))
        }
        .glassCard()
    }

    private func stat(_ value: Int, _ title: LocalizedStringResource, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value, format: .number)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
