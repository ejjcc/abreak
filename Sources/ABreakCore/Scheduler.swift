import Foundation

public struct SchedulerConfig: Equatable, Sendable {
    public var workInterval: TimeInterval = 20 * 60
    public var shortBreak: TimeInterval = 20
    public var longBreak: TimeInterval = 5 * 60
    /// Every Nth break is a long break; 0 disables long breaks.
    public var longBreakEvery = 4
    public var preBreakWarning: TimeInterval = 10
    /// User idle this long stops the work countdown.
    public var idlePauseAfter: TimeInterval = 60
    /// User idle this long counts as a natural break and resets the work countdown.
    public var idleResetAfter: TimeInterval = 5 * 60
    /// Minimum work time left after a smart pause ends, so a break never fires right on resume.
    public var resumeCooldown: TimeInterval = 60

    public init() {}
}

public enum Phase: Equatable, Sendable {
    case working
    case preBreak
    case onBreak(long: Bool)
}

public enum AbsenceReason: Hashable, Sendable {
    case screenLock, sleep, inactiveSession
}

/// Pure break-timer state machine. The caller drives it with `tick` once per second.
public struct Scheduler: Sendable {
    public var config: SchedulerConfig {
        didSet { workRemaining = min(workRemaining, config.workInterval) }
    }
    public private(set) var phase: Phase = .working
    public private(set) var workRemaining: TimeInterval
    public private(set) var breakRemaining: TimeInterval = 0
    public private(set) var completedBreaks = 0
    public private(set) var pauseReasons: [String] = []
    public private(set) var isIdle = false
    private var absenceReasons: Set<AbsenceReason> = []
    private var absentSince: Date?
    public var isAway: Bool { !absenceReasons.isEmpty }

    /// Lock and sleep often overlap. Credit their combined wall-clock duration only once.
    /// Returns true when the absence satisfies a break and starts a fresh work interval.
    @discardableResult
    public mutating func setAbsent(_ reason: AbsenceReason, _ active: Bool, at now: Date) -> Bool {
        if active {
            if absenceReasons.isEmpty { absentSince = now }
            absenceReasons.insert(reason)
            return false
        }
        guard absenceReasons.remove(reason) != nil, absenceReasons.isEmpty,
              let started = absentSince else { return false }
        absentSince = nil
        let duration = max(0, now.timeIntervalSince(started))
        let naturalRest = config.longBreakEvery > 0
            ? min(config.longBreak, config.idleResetAfter) : config.idleResetAfter
        if duration >= naturalRest {
            // A full long rest also restarts the short/long-break cycle.
            completedBreaks = 0
            resetWork()
            isIdle = false
            return true
        }
        if case .onBreak = phase {
            breakRemaining = max(0, breakRemaining - duration)
            if breakRemaining == 0 {
                completedBreaks += 1
                resetWork()
                isIdle = false
                return true
            }
        }
        return false
    }

    public init(config: SchedulerConfig = .init()) {
        self.config = config
        workRemaining = config.workInterval
    }

    public var isPaused: Bool { !pauseReasons.isEmpty }

    public var nextBreakIsLong: Bool {
        config.longBreakEvery > 0 && (completedBreaks + 1) % config.longBreakEvery == 0
    }

    public mutating func tick(_ dt: TimeInterval, idle: TimeInterval, pauseReasons reasons: [String]) {
        let wasPaused = isPaused
        pauseReasons = reasons

        // Elapsed absence is reconciled at unlock/wake, never by capped UI timer ticks.
        if isAway { return }

        if isPaused {
            // A smart pause (remote session, meeting...) cancels any pending or running break.
            if phase != .working {
                resetWork()
            }
            isIdle = false
            return
        }
        if wasPaused {
            workRemaining = max(workRemaining, config.resumeCooldown)
        }

        switch phase {
        case .working, .preBreak:
            if idle >= config.idleResetAfter {
                isIdle = true
                resetWork()
                return
            }
            isIdle = idle >= config.idlePauseAfter
            if isIdle { return }
            workRemaining -= dt
            if workRemaining <= 0 {
                startBreak()
            } else {
                phase = workRemaining <= config.preBreakWarning ? .preBreak : .working
            }
        case .onBreak:
            breakRemaining -= dt
            if breakRemaining <= 0 {
                completedBreaks += 1
                resetWork()
            }
        }
    }

    /// No-op while paused: a smart pause would cancel the break on the next tick anyway.
    public mutating func startBreak() {
        guard !isPaused, !isAway else { return }
        if case .onBreak = phase { return }
        let long = nextBreakIsLong
        phase = .onBreak(long: long)
        breakRemaining = long ? config.longBreak : config.shortBreak
    }

    public mutating func skipBreak() {
        resetWork()
    }

    public mutating func postpone(_ seconds: TimeInterval) {
        phase = .working
        workRemaining = seconds
    }

    public mutating func resetWork() {
        phase = .working
        breakRemaining = 0
        workRemaining = config.workInterval
    }
}
