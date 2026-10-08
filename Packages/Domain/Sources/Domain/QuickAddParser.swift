import Foundation

/// 1行の文から読み取った、タスクの内容。
public struct QuickAdd: Equatable, Sendable {
    public var title: String
    public var dueAt: Date?
    public var estimateMinutes: Int?

    public init(title: String, dueAt: Date? = nil, estimateMinutes: Int? = nil) {
        self.title = title
        self.dueAt = dueAt
        self.estimateMinutes = estimateMinutes
    }

    /// 締切か所要時間のどちらかを読み取れたか。
    public var hasDetails: Bool { dueAt != nil || estimateMinutes != nil }
}

/// 「金曜までにレポート 2時間」のような1行から、名前、締切、所要時間を読み取る。
///
/// 入力の手間を減らすためのもの。日本語と英語の、よくある書き方だけを決まった規則で読む。
/// 読み取れなかった部分は、そのまま名前に残す。
public struct QuickAddParser: Sendable {
    public var calendar: Calendar

    /// 日付だけが書かれていたときの時刻。提出物の締切に多い 23:59 にする。
    private static let defaultTime = (hour: 23, minute: 59)

    public init(calendar: Calendar) {
        self.calendar = calendar
    }

    public func parse(_ text: String, now: Date) -> QuickAdd {
        // 全角の数字や記号を半角にそろえてから読む。
        var rest = Self.halfWidthASCII(text)

        // 「2時間」を先に取り除く。あとで「18時」を時刻として読むときに、取り違えないため。
        let minutes = extractDuration(from: &rest)
        let day = extractDay(from: &rest, now: now)
        let time = extractTime(from: &rest)

        return QuickAdd(
            title: Self.cleanTitle(rest),
            dueAt: dueDate(day: day, time: time, now: now),
            estimateMinutes: minutes
        )
    }

    /// 全角の英数字と記号だけを半角にする。
    /// 標準の変換はカタカナまで半角にしてしまい、名前が変わってしまうので使わない。
    private static func halfWidthASCII(_ text: String) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.map { scalar in
            switch scalar.value {
            case 0xFF01...0xFF5E: Unicode.Scalar(scalar.value - 0xFEE0) ?? scalar
            case 0x3000: " "
            default: scalar
            }
        }))
    }

    // MARK: - 所要時間

    private func extractDuration(from text: inout String) -> Int? {
        // 「1時間30分」「1時間半」「2h」「1.5時間」「1h30m」
        if let match = Self.firstMatch(
            #"(\d+(?:\.\d+)?)\s*(?:時間|hours?|hrs?|h(?![a-z]))\s*(?:(\d+)\s*(?:分|minutes?|mins?|m(?![a-z]))|(半))?"#,
            in: text
        ) {
            let hours = Double(match.groups[0] ?? "") ?? 0
            let extra = Int(match.groups[1] ?? "") ?? (match.groups[2] != nil ? 30 : 0)
            text.removeSubrange(match.range)
            return Int((hours * 60).rounded()) + extra
        }
        // 「90分」「45min」
        if let match = Self.firstMatch(#"(\d+)\s*(?:分|minutes?|mins?|m(?![a-z]))"#, in: text) {
            text.removeSubrange(match.range)
            return Int(match.groups[0] ?? "")
        }
        return nil
    }

    // MARK: - 日付

    private func extractDay(from text: inout String, now: Date) -> Date? {
        let today = calendar.startOfDay(for: now)

        // 「10/12」「10月12日」
        if let match = Self.firstMatch(#"(\d{1,2})\s*(?:/|月)\s*(\d{1,2})日?"#, in: text),
           let month = Int(match.groups[0] ?? ""), let day = Int(match.groups[1] ?? "")
        {
            var parts = calendar.dateComponents([.year], from: now)
            parts.month = month
            parts.day = day
            if var date = calendar.date(from: parts), (1...12).contains(month), (1...31).contains(day) {
                // もう過ぎた日付なら、来年のこととして読む。
                if date < today {
                    date = calendar.date(byAdding: .year, value: 1, to: date) ?? date
                }
                text.removeSubrange(match.range)
                return date
            }
        }

        // 「明後日」は「明日」より先に調べる(「明日」を含まないが、念のため長い語から)。
        let relative: [(pattern: String, offset: Int)] = [
            (#"明後日|あさって|day after tomorrow"#, 2),
            (#"明日|あした|あす|\btomorrow\b|\btmrw?\b"#, 1),
            (#"今日|きょう|本日|\btoday\b|\btonight\b"#, 0),
        ]
        for entry in relative {
            if let match = Self.firstMatch(entry.pattern, in: text) {
                text.removeSubrange(match.range)
                return calendar.date(byAdding: .day, value: entry.offset, to: today)
            }
        }

        // 「金曜」「来週の月曜日」
        if let match = Self.firstMatch(#"(来週の?)?\s*([月火水木金土日])曜日?"#, in: text),
           let symbol = match.groups[1], let weekday = Self.japaneseWeekdays[symbol]
        {
            text.removeSubrange(match.range)
            return nextDate(weekday: weekday, nextWeek: match.groups[0] != nil, from: today)
        }
        // "Friday", "next Mon"
        if let match = Self.firstMatch(
            #"\b(next\s+)?(mon|tue|wed|thu|fri|sat|sun)(?:day|sday|nesday|rsday|urday)?\b"#,
            in: text
        ), let symbol = match.groups[1]?.lowercased(), let weekday = Self.englishWeekdays[symbol] {
            text.removeSubrange(match.range)
            return nextDate(weekday: weekday, nextWeek: match.groups[0] != nil, from: today)
        }
        return nil
    }

    /// 次に来るその曜日。今日がその曜日なら今日。「来週」と書かれていれば、さらに1週間先。
    private func nextDate(weekday: Int, nextWeek: Bool, from today: Date) -> Date? {
        let current = calendar.component(.weekday, from: today)
        var offset = (weekday - current + 7) % 7
        if nextWeek {
            offset += 7
        }
        return calendar.date(byAdding: .day, value: offset, to: today)
    }

    private static let japaneseWeekdays = ["日": 1, "月": 2, "火": 3, "水": 4, "木": 5, "金": 6, "土": 7]
    private static let englishWeekdays = ["sun": 1, "mon": 2, "tue": 3, "wed": 4, "thu": 5, "fri": 6, "sat": 7]

    // MARK: - 時刻

    private func extractTime(from text: inout String) -> (hour: Int, minute: Int)? {
        // 「23:59」「午後6:30」「6:30pm」
        if let match = Self.firstMatch(#"(午前|午後|am|pm)?\s*(\d{1,2}):(\d{2})\s*(am|pm)?"#, in: text),
           let hour = Int(match.groups[1] ?? ""), let minute = Int(match.groups[2] ?? ""),
           let time = Self.time(hour: hour, minute: minute, marker: match.groups[0] ?? match.groups[3])
        {
            text.removeSubrange(match.range)
            return time
        }
        // 「18時」「午後6時半」「9時30分」
        if let match = Self.firstMatch(#"(午前|午後)?\s*(\d{1,2})時(?:(\d{1,2})分|(半))?"#, in: text),
           let hour = Int(match.groups[1] ?? "")
        {
            let minute = Int(match.groups[2] ?? "") ?? (match.groups[3] != nil ? 30 : 0)
            if let time = Self.time(hour: hour, minute: minute, marker: match.groups[0]) {
                text.removeSubrange(match.range)
                return time
            }
        }
        // "6pm", "9 am"
        if let match = Self.firstMatch(#"\b(\d{1,2})\s*(am|pm)\b"#, in: text),
           let hour = Int(match.groups[0] ?? ""),
           let time = Self.time(hour: hour, minute: 0, marker: match.groups[1])
        {
            text.removeSubrange(match.range)
            return time
        }
        return nil
    }

    private static func time(hour: Int, minute: Int, marker: String?) -> (hour: Int, minute: Int)? {
        var hour = hour
        switch marker?.lowercased() {
        case "午後", "pm":
            if hour < 12 { hour += 12 }
        case "午前", "am":
            if hour == 12 { hour = 0 }
        default:
            break
        }
        guard (0...24).contains(hour), (0...59).contains(minute) else { return nil }
        // 「24時」は、その日の終わりとして 23:59 に読み替える。
        return hour == 24 ? (23, 59) : (hour, minute)
    }

    // MARK: - 締切の組み立て

    private func dueDate(day: Date?, time: (hour: Int, minute: Int)?, now: Date) -> Date? {
        guard day != nil || time != nil else { return nil }
        let time = time ?? Self.defaultTime
        let base = day ?? calendar.startOfDay(for: now)
        guard let date = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: base) else {
            return nil
        }
        // 時刻だけが書かれていて、今日のその時刻をもう過ぎているなら、明日のこととして読む。
        if day == nil, date <= now {
            return calendar.date(byAdding: .day, value: 1, to: date)
        }
        return date
    }

    // MARK: - 名前の整理

    /// 日付などを取り除いたあとに残る、つなぎの言葉と記号を落とす。
    private static func cleanTitle(_ text: String) -> String {
        let particles = ["までに", "まで", "迄に", "迄", "締切", "〆切", "に", "の", "は", "を", "で", "by", "due", "until", "before", "on", "at", "for", "in"]
        let trimSet = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "、。,.・-:;()()"))
        var title = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: trimSet)

        var changed = true
        while changed {
            changed = false
            for particle in particles {
                let lowered = title.lowercased()
                // 英語のつなぎ言葉は、単語として独立しているときだけ落とす(「Design」の末尾の in などを削らない)。
                let isWord = particle.allSatisfy(\.isASCII)
                if lowered.hasSuffix(particle), !isWord || lowered.dropLast(particle.count).last.map({ $0 == " " }) ?? true {
                    title = String(title.dropLast(particle.count)).trimmingCharacters(in: trimSet)
                    changed = true
                }
                let loweredAgain = title.lowercased()
                if loweredAgain.hasPrefix(particle),
                   !isWord || loweredAgain.dropFirst(particle.count).first.map({ $0 == " " }) ?? true
                {
                    title = String(title.dropFirst(particle.count)).trimmingCharacters(in: trimSet)
                    changed = true
                }
            }
        }
        return title
    }

    // MARK: - 正規表現

    private struct Match {
        var range: Range<String.Index>
        /// かっこで囲んだ部分。一致しなかったものは nil。
        var groups: [String?]
    }

    private static func firstMatch(_ pattern: String, in text: String) -> Match? {
        guard
            let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
            let result = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            let range = Range(result.range, in: text)
        else { return nil }
        let groups = (1..<result.numberOfRanges).map { index -> String? in
            Range(result.range(at: index), in: text).map { String(text[$0]) }
        }
        return Match(range: range, groups: groups)
    }
}
