import Foundation

/// Debounces a noisy boolean signal: turns on after `onAfter` consecutive positive samples,
/// turns off once no positive sample has been seen for `offAfter` seconds.
public struct ActivityLatch: Sendable {
    public var onAfter: Int
    public var offAfter: TimeInterval
    public private(set) var isOn = false
    private var streak = 0
    private var lastPositive: Date?

    public init(onAfter: Int = 2, offAfter: TimeInterval = 20) {
        self.onAfter = onAfter
        self.offAfter = offAfter
    }

    @discardableResult
    public mutating func update(_ positive: Bool, at now: Date) -> Bool {
        if positive {
            streak += 1
            lastPositive = now
            if streak >= onAfter { isOn = true }
        } else {
            streak = 0
            if isOn, let last = lastPositive, now.timeIntervalSince(last) >= offAfter { isOn = false }
        }
        return isOn
    }
}
