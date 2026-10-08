import ComposableArchitecture
import DesignSystem
import Domain
import SwiftUI

struct GoalEditorView: View {
    @Bindable var store: StoreOf<GoalEditorFeature>
    @FocusState private var isTitleFocused: Bool

    private var tint: Color { store.goal.tint.color }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(text: $store.goal.title) {
                        Text(.goalTitlePlaceholder)
                    }
                    .font(.title3.weight(.semibold))
                    .focused($isTitleFocused)
                    .accessibilityIdentifier("goalEditor.title")
                    symbolPicker
                    tintPicker
                }

                Section {
                    MinutesPicker(
                        minutes: $store.goal.dailyMinutes,
                        range: GoalEditorFeature.minutesRange,
                        step: GoalEditorFeature.minutesStep,
                        presets: GoalEditorFeature.minutesPresets,
                        tint: tint
                    )
                } header: {
                    Text(.goalDailyHeader)
                } footer: {
                    Text(.goalDailyFooter)
                }

                Section {
                    weekdayPicker
                } header: {
                    Text(.goalWeekdaysHeader)
                }

                Section {
                    Picker(selection: $store.locksAtTime) {
                        Text(.goalLockFromMorning).tag(false)
                        Text(.goalLockAtTime).tag(true)
                    } label: {
                        Text(.goalLockHeader)
                    }
                    .pickerStyle(.segmented)
                    if store.locksAtTime {
                        DatePicker(selection: lockTime, displayedComponents: .hourAndMinute) {
                            Text(.goalLockTime)
                        }
                    }
                } header: {
                    Text(.goalLockHeader)
                } footer: {
                    Text(store.locksAtTime ? .goalLockAtTimeFooter : .goalLockFromMorningFooter)
                }

                if !store.isNew {
                    Section {
                        HoldToConfirmButton(tint: .red) {
                            store.send(.deleteConfirmed)
                        } label: {
                            Text(.goalDeleteHold)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    } footer: {
                        Text(.goalDeleteFooter)
                    }
                }
            }
            .navigationTitle(Text(store.isNew ? .goalNewTitle : .goalEditTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        store.send(.cancelTapped)
                    } label: {
                        Text(.commonCancel)
                    }
                    .accessibilityIdentifier("goalEditor.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        store.send(.saveTapped)
                    } label: {
                        Text(store.isNew ? .commonAdd : .commonSave)
                    }
                    .disabled(!store.canSave)
                    .accessibilityIdentifier("goalEditor.save")
                }
            }
            .tint(tint)
            .onAppear { isTitleFocused = store.isNew }
        }
    }

    private var symbolPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(GoalEditorFeature.symbols, id: \.self) { symbol in
                    let isSelected = symbol == store.goal.symbol
                    Button {
                        store.goal.symbol = symbol
                    } label: {
                        Image(systemName: symbol)
                            .font(.body.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .foregroundStyle(isSelected ? .black.opacity(0.85) : .primary)
                            .background(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(.quaternary), in: .circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: store.goal.symbol)
    }

    private var tintPicker: some View {
        HStack(spacing: 0) {
            ForEach(Goal.Tint.allCases, id: \.self) { candidate in
                Button {
                    store.goal.tint = candidate
                } label: {
                    Circle()
                        .fill(candidate.color)
                        .frame(width: 28, height: 28)
                        .overlay {
                            if candidate == store.goal.tint {
                                Circle().strokeBorder(.white, lineWidth: 3)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(candidate.rawValue))
                .accessibilityAddTraits(candidate == store.goal.tint ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: store.goal.tint)
    }

    private var weekdayPicker: some View {
        HStack(spacing: 0) {
            ForEach(WeekdayText.mondayFirst, id: \.self) { weekday in
                let isOn = store.goal.weekdays.contains(weekday)
                Button {
                    store.send(.weekdayTapped(weekday))
                } label: {
                    Text(WeekdayText.veryShort(weekday))
                        .font(.subheadline.weight(.bold))
                        .frame(width: 38, height: 38)
                        .foregroundStyle(isOn ? .black.opacity(0.85) : .secondary)
                        .background(isOn ? AnyShapeStyle(tint) : AnyShapeStyle(.quaternary), in: .circle)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(WeekdayText.full(weekday)))
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: store.goal.weekdays)
    }

    /// 「0 時からの分」と、DatePicker が扱う Date を変換する。日付の部分は使わない。
    private var lockTime: Binding<Date> {
        Binding {
            let midnight = Calendar.current.startOfDay(for: .now)
            return Calendar.current.date(byAdding: .minute, value: store.lockTimeMinutes, to: midnight) ?? midnight
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            store.send(.lockTimeChanged(minutes: (parts.hour ?? 0) * 60 + (parts.minute ?? 0)))
        }
    }
}

/// 曜日の表示。
enum WeekdayText {
    static let mondayFirst: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]

    static func veryShort(_ weekday: Weekday) -> String {
        Calendar.current.veryShortStandaloneWeekdaySymbols[weekday.rawValue - 1]
    }

    static func short(_ weekday: Weekday) -> String {
        Calendar.current.shortStandaloneWeekdaySymbols[weekday.rawValue - 1]
    }

    static func full(_ weekday: Weekday) -> String {
        Calendar.current.standaloneWeekdaySymbols[weekday.rawValue - 1]
    }

    /// 「毎日」「平日」「月・水・金」のような要約。
    static func summary(_ weekdays: Set<Weekday>) -> String {
        if weekdays == Weekday.everyDay { return String(localized: .weekdaysEveryDay) }
        if weekdays == Weekday.weekdaysOnly { return String(localized: .weekdaysWeekdays) }
        return mondayFirst.filter(weekdays.contains).map(short).formatted(.list(type: .and, width: .narrow))
    }
}
