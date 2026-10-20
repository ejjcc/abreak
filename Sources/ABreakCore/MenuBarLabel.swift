import Foundation

public enum MenuBarTimerStyle: Int, CaseIterable, Sendable {
    /// "44:59", changes every second.
    case countdown = 0
    /// "45m", changes every minute.
    case minutes = 1
    /// Icon only.
    case iconOnly = 2
}

/// What the status item shows. The remaining time stays visible (frozen) while paused,
/// so the user can always tell the app is running and how far the next break is.
public struct MenuBarLabel: Equatable, Sendable {
    public var symbol: String
    public var text: String
    /// Rendered with a secondary color: the timer is not counting down.
    public var dimmed: Bool

    public init(symbol: String, text: String, dimmed: Bool) {
        self.symbol = symbol
        self.text = text
        self.dimmed = dimmed
    }

    public init(_ s: Scheduler, style: MenuBarTimerStyle) {
        let onBreak: Bool
        if case .onBreak = s.phase { onBreak = true } else { onBreak = false }
        let remaining = onBreak ? s.breakRemaining : s.workRemaining

        if s.isPaused {
            symbol = "pause.circle"
        } else if onBreak {
            symbol = "eye.slash"
        } else if s.isIdle {
            symbol = "moon.zzz"
        } else {
            symbol = "eye"
        }
        switch style {
        case .countdown: text = DurationFormat.clock(remaining)
        case .minutes: text = DurationFormat.compact(remaining)
        case .iconOnly: text = ""
        }
        dimmed = s.isPaused || s.isIdle
    }
}
