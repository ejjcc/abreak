import Foundation

/// Detects two presses within `window` seconds; a third press starts a new pair.
public struct DoublePress: Sendable {
    public var window: TimeInterval
    private var last: Date?

    public init(window: TimeInterval = 1) {
        self.window = window
    }

    public mutating func press(at now: Date) -> Bool {
        if let last, now.timeIntervalSince(last) < window {
            self.last = nil
            return true
        }
        last = now
        return false
    }
}
