import Foundation

/// Fires once every `interval` seconds of active (non-paused, non-idle) work time.
public struct IntervalReminder: Sendable {
    public var interval: TimeInterval
    public private(set) var elapsed: TimeInterval = 0

    public init(interval: TimeInterval) {
        self.interval = interval
    }

    public mutating func tick(_ dt: TimeInterval, active: Bool) -> Bool {
        guard active, interval > 0 else { return false }
        elapsed += dt
        guard elapsed >= interval else { return false }
        elapsed = 0
        return true
    }

    public mutating func reset() {
        elapsed = 0
    }
}
