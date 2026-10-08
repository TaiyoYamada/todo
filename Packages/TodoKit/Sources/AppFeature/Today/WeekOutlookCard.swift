import DesignSystem
import Domain
import SwiftUI

/// これからの7日の、ロックの見込み。天気予報のように、どの日が荒れそうかをひと目で見せる。
struct WeekOutlookCard: View {
    let days: [DayOutlook]
    @Environment(\.mood) private var mood

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(.todayWeekTitle)
                .accessibilityIdentifier("today.week.title")
                .sectionLabelStyle()
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                    cell(day, isToday: index == 0)
                }
            }
        }
        .foregroundStyle(.white)
        .glassCard()
    }

    private func cell(_ day: DayOutlook, isToday: Bool) -> some View {
        VStack(spacing: 8) {
            Group {
                if isToday {
                    Text(.commonToday)
                } else {
                    Text(day.dayStart, format: .dateTime.weekday(.abbreviated))
                }
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(isToday ? mood.accent : .white.opacity(0.65))
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            Image(systemName: symbol(for: day.severity))
                .symbolRenderingMode(.multicolor)
                .font(.title3)
                .frame(height: 26)

            Group {
                if let first = day.firstLockAt {
                    if first == day.dayStart {
                        Text(.todayForecastFromMorning)
                    } else {
                        Text(TimeText.clock(first))
                    }
                } else {
                    Text(verbatim: "–")
                }
            }
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(day.firstLockAt == nil ? 0.35 : 0.85))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(day.dayStart, format: .dateTime.weekday(.wide).month().day()))
        .accessibilityValue(Text(description(for: day)))
    }

    /// 荒れ具合を、天気の記号で表す。
    private func symbol(for severity: DayOutlook.Severity) -> String {
        switch severity {
        case .clear: "sun.max.fill"
        case .routine: "cloud.sun.fill"
        case .deadline: "cloud.fill"
        case .heavy: "cloud.bolt.fill"
        }
    }

    private func description(for day: DayOutlook) -> LocalizedStringResource {
        switch day.severity {
        case .clear: .todayWeekClear
        case .routine: .todayWeekRoutine
        case .deadline, .heavy: .todayWeekDeadlines(day.pendingTaskCount)
        }
    }
}
