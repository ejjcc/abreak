import Foundation

public enum DurationFormat {
    /// Menu bar style: whole minutes rounded up ("45m"), seconds under a minute ("30s").
    public static func compact(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded(.up)))
        return s >= 60 ? "\((s + 59) / 60)m" : "\(s)s"
    }

    /// Countdown style: "MM:SS".
    public static func clock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded(.up)))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}
