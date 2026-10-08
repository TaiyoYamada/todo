import DesignSystem
import Domain
import SharedCore
import SwiftUI
import WidgetKit

/// 次のロックまでの余裕を、ホーム画面とロック画面に出すウィジェット。
public struct SlackWidget: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SlackWidget", provider: SlackProvider()) { entry in
            SlackWidgetView(entry: entry)
        }
        .configurationDisplayName(Text(.widgetSlackName))
        .description(Text(.widgetSlackDescription))
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct SlackEntry: TimelineEntry {
    let date: Date
    /// 写しがまだない(アプリを一度も開いていない)ときは nil。
    let status: LockStatus?

    static func placeholder(at date: Date) -> SlackEntry {
        SlackEntry(date: date, status: nil)
    }
}

struct SlackProvider: TimelineProvider {
    /// 1 回の更新で先読みする、状態の変わり目の数。
    private static let lookahead = 8

    func placeholder(in _: Context) -> SlackEntry {
        .placeholder(at: .now)
    }

    func getSnapshot(in _: Context, completion: @escaping @Sendable (SlackEntry) -> Void) {
        completion(entries(from: .now).first ?? .placeholder(at: .now))
    }

    func getTimeline(in _: Context, completion: @escaping @Sendable (Timeline<SlackEntry>) -> Void) {
        let entries = entries(from: .now)
        // 先読みしたぶんを使い切ったら、もう一度作り直してもらう。
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    /// いまの状態と、時間の経過だけで状態が変わる時刻ごとの状態を並べる。
    /// カウントダウンの数字は OS が毎秒描き直すので、変わり目だけ用意すれば足りる。
    private func entries(from now: Date) -> [SlackEntry] {
        guard let snapshot = SnapshotStore.load() else { return [.placeholder(at: now)] }
        let engine = LockEngine(calendar: .current)
        var entries: [SlackEntry] = []
        var date = now
        for _ in 0..<Self.lookahead {
            let status = engine.status(world: snapshot.world, now: date)
            entries.append(SlackEntry(date: date, status: status))
            guard let next = status.nextChangeAt, next > date else { break }
            date = next
        }
        return entries
    }
}

/// ウィジェットに出す内容。ロックの状態から決まる。
enum SlackContent {
    case setup
    case locked(title: String, remainingSeconds: Int?, others: Int)
    case onPass(until: Date)
    case countdown(until: Date, title: String?)
    case free(nextLockAt: Date?)

    init(entry: SlackEntry) {
        guard let status = entry.status else {
            self = .setup
            return
        }
        switch status.phase {
        case .locked:
            let primary = status.activeReasons.first
            self = .locked(
                title: primary?.title ?? "",
                remainingSeconds: primary?.remainingSeconds,
                others: max(0, status.activeReasons.count - 1)
            )
        case let .onPass(until):
            self = .onPass(until: until)
        case let .free(nextLockAt):
            if let nextLockAt, nextLockAt < status.today.end {
                self = .countdown(
                    until: nextLockAt,
                    title: status.upcomingReasons.first { $0.startsAt == nextLockAt }?.title
                )
            } else if status.goals.isEmpty, status.upcomingReasons.isEmpty, nextLockAt == nil {
                self = .setup
            } else {
                self = .free(nextLockAt: nextLockAt)
            }
        }
    }

    var mood: Mood {
        switch self {
        case .setup: .calm
        case .locked: .locked
        case .onPass: .warning
        case .countdown: .calm
        case .free: .free
        }
    }
}

struct SlackWidgetView: View {
    let entry: SlackEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let content = SlackContent(entry: entry)
        switch family {
        case .accessoryInline:
            inline(content)
        case .accessoryRectangular:
            rectangular(content)
                .containerBackground(for: .widget) { Color.clear }
        default:
            home(content)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [content.mood.backdrop[1], content.mood.backdrop[2], content.mood.backdrop[3]],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
    }

    // MARK: ホーム画面

    private func home(_ content: SlackContent) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            label(content)
                .font(.caption2.weight(.bold))
                .foregroundStyle(content.mood.accent)
            Spacer(minLength: 0)
            headline(content)
                .font(.system(size: family == .systemSmall ? 30 : 40, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(family == .systemSmall ? 2 : 1)
            detail(content)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(2)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func label(_ content: SlackContent) -> some View {
        switch content {
        case .setup:
            Label { Text(.widgetLabelSetup) } icon: { Image(systemName: "sparkles") }
        case .locked:
            Label { Text(.widgetLabelLocked) } icon: { Image(systemName: "lock.fill") }
        case .onPass:
            Label { Text(.widgetLabelPass) } icon: { Image(systemName: "hourglass") }
        case .countdown:
            Label { Text(.widgetLabelSlack) } icon: { Image(systemName: "timer") }
        case .free:
            Label { Text(.widgetLabelFree) } icon: { Image(systemName: "checkmark.seal.fill") }
        }
    }

    @ViewBuilder
    private func headline(_ content: SlackContent) -> some View {
        switch content {
        case .setup:
            Text(.widgetHeadlineSetup)
        case let .locked(title, _, _):
            Text(title)
        case let .onPass(until), let .countdown(until, _):
            Text(timerInterval: entry.date...max(until, entry.date), countsDown: true)
        case .free:
            Text(.widgetHeadlineFree)
        }
    }

    @ViewBuilder
    private func detail(_ content: SlackContent) -> some View {
        switch content {
        case .setup:
            EmptyView()
        case let .locked(_, remainingSeconds, others):
            if let remainingSeconds {
                Text(.widgetDetailRemaining(DurationText.compact(seconds: remainingSeconds)))
            } else if others > 0 {
                Text(.widgetDetailOthers(others))
            } else {
                Text(.widgetDetailFinish)
            }
        case .onPass:
            Text(.widgetDetailPass)
        case let .countdown(until, title):
            if let title {
                Text(.widgetDetailReason(until.formatted(date: .omitted, time: .shortened), title))
            }
        case let .free(nextLockAt):
            if let nextLockAt {
                Text(.widgetDetailNext(nextLockAt.formatted(date: .omitted, time: .shortened)))
            }
        }
    }

    // MARK: ロック画面

    private func rectangular(_ content: SlackContent) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            label(content)
                .font(.caption2.weight(.semibold))
            headline(content)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            detail(content)
                .font(.caption2)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func inline(_ content: SlackContent) -> some View {
        switch content {
        case .setup:
            Text(.widgetHeadlineSetup)
        case let .locked(title, _, _):
            Label { Text(title) } icon: { Image(systemName: "lock.fill") }
        case let .onPass(until), let .countdown(until, _):
            Label {
                Text(timerInterval: entry.date...max(until, entry.date), countsDown: true)
            } icon: {
                Image(systemName: "timer")
            }
        case .free:
            Label { Text(.widgetHeadlineFree) } icon: { Image(systemName: "checkmark.seal") }
        }
    }
}
