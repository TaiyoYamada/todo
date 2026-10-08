import Foundation

/// 時間の長さを、言語に合わせた短い文字列にする。
public enum DurationText {
    /// 「2時間14分」「2h 14m」のような形。1分未満は切り上げて1分とする。
    public static func compact(seconds: Int) -> String {
        let minutes = max(1, Int((Double(seconds) / 60).rounded(.up)))
        return Duration.seconds(minutes * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .narrow, zeroValueUnits: .hide))
    }

    public static func compact(minutes: Int) -> String {
        Duration.seconds(minutes * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .narrow, zeroValueUnits: .hide))
    }
}
