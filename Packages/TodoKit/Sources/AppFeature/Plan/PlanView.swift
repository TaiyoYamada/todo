import ComposableArchitecture
import DesignSystem
import Domain
import SwiftUI

struct PlanView: View {
    let store: StoreOf<PlanFeature>
    private let mood = Mood.calm

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    goals
                    tasks
                    if !store.closedTasks.isEmpty {
                        closedTasks
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background { AuroraBackground(mood: mood) }
            .navigationTitle(Text(.tabPlan))
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .environment(\.mood, mood)
        .foregroundStyle(.white)
    }

    private var goals: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(.planGoalsTitle)
                .sectionLabelStyle()
            ForEach(store.board.world.activeGoals) { goal in
                Button {
                    store.send(.goalTapped(goal.id))
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: goal.symbol)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.black.opacity(0.8))
                            .frame(width: 44, height: 44)
                            .background(goal.tint.color.gradient, in: .circle)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(goal.title)
                                .font(.body.weight(.semibold))
                                .lineLimit(1)
                            Text(subtitle(for: goal))
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            addButton(.todayAddGoal) { store.send(.addGoalTapped) }
        }
        .glassCard()
    }

    private var tasks: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(.planTasksTitle)
                .sectionLabelStyle()
            ForEach(store.openTasks) { task in
                let limit = store.board.world.startLimit(of: task)
                let isPastLimit = limit <= store.board.status.now
                HStack(spacing: 14) {
                    Button {
                        store.send(.completeTaskTapped(task.id))
                    } label: {
                        Image(systemName: "circle")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(Text(.todayCtaCompleteTask))

                    Button {
                        store.send(.taskTapped(task.id))
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(task.title)
                                .font(.body.weight(.semibold))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Text(
                                .planTaskDetail(
                                    TimeText.dayAndClock(task.dueAt),
                                    DurationText.compact(minutes: task.estimateMinutes)
                                )
                            )
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.65))
                            Label {
                                Text(.todayTasksStartLimit(TimeText.dayAndClock(limit)))
                            } icon: {
                                Image(systemName: isPastLimit ? "lock.fill" : "lock.open")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isPastLimit ? Mood.locked.accent : .white.opacity(0.75))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            addButton(.todayAddTask) { store.send(.addTaskTapped) }
        }
        .glassCard()
    }

    private var closedTasks: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.planClosedTitle)
                .sectionLabelStyle()
            ForEach(store.closedTasks) { task in
                Button {
                    store.send(.taskTapped(task.id))
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: task.withdrawnAt == nil ? "checkmark.circle.fill" : "minus.circle")
                            .foregroundStyle(.white.opacity(0.5))
                        Text(task.title)
                            .strikethrough(task.withdrawnAt == nil, color: .white.opacity(0.4))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .font(.subheadline)
                    .frame(minHeight: 32)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .glassCard()
    }

    private func addButton(_ title: LocalizedStringResource, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: "plus.circle.fill")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(mood.accent)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
    }

    private func subtitle(for goal: Goal) -> String {
        let lock: String =
            switch goal.lockStart {
            case .dayStart:
                String(localized: .goalLockFromMorning)
            case let .timeOfDay(minutes):
                String(format: "%d:%02d", minutes / 60, minutes % 60)
            }
        return [DurationText.compact(minutes: goal.dailyMinutes), WeekdayText.summary(goal.weekdays), lock]
            .joined(separator: " · ")
    }
}
