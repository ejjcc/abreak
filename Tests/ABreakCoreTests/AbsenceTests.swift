import Foundation
import Testing
@testable import ABreakCore

private let epoch = Date(timeIntervalSince1970: 0)

private func schedulerBeforeLongBreak() -> Scheduler {
    var c = SchedulerConfig()
    c.workInterval = 2700
    c.shortBreak = 30
    c.longBreak = 180
    c.longBreakEvery = 4
    c.idleResetAfter = 300
    var s = Scheduler(config: c)
    for _ in 0..<3 {
        s.startBreak()
        s.tick(30, idle: 0, pauseReasons: [])
    }
    #expect(s.nextBreakIsLong)
    return s
}

@Test func threeMinuteLockRestartsWorkAndLongBreakCycle() {
    for duringBreak in [false, true] {
        var s = schedulerBeforeLongBreak()
        if duringBreak { s.startBreak() }
        s.setAbsent(.screenLock, true, at: epoch)
        s.tick(5, idle: 0, pauseReasons: [])
        let settled1 = s.setAbsent(.screenLock, false, at: epoch.addingTimeInterval(180))
        #expect(settled1)
        #expect(s.phase == .working)
        #expect(s.workRemaining == 2700)
        #expect(s.completedBreaks == 0)
        #expect(!s.nextBreakIsLong)
        s.tick(60, idle: 0, pauseReasons: [])
        #expect(s.workRemaining == 2640)
        #expect(s.phase == .working)
    }
}

@Test func shortLockCreditsElapsedTimeWithoutRestartingLongBreak() {
    var s = schedulerBeforeLongBreak()
    s.startBreak()
    s.tick(40, idle: 0, pauseReasons: [])
    s.setAbsent(.screenLock, true, at: epoch)
    // Even many UI ticks while locked must not consume the break twice.
    for _ in 0..<100 { s.tick(1, idle: 0, pauseReasons: []) }
    #expect(s.breakRemaining == 140)
    let settled2 = s.setAbsent(.screenLock, false, at: epoch.addingTimeInterval(100))
    #expect(!settled2)
    #expect(s.breakRemaining == 40)
    s.tick(40, idle: 0, pauseReasons: [])
    #expect(s.phase == .working)
    #expect(s.completedBreaks == 4)
    #expect(s.workRemaining == 2700)
}

@Test func lockCompletesPendingBreakExactlyOnce() {
    var s = schedulerBeforeLongBreak()
    s.startBreak()
    s.tick(60, idle: 0, pauseReasons: [])
    s.setAbsent(.screenLock, true, at: epoch)
    let settled3 = s.setAbsent(.screenLock, false, at: epoch.addingTimeInterval(120))
    #expect(settled3)
    #expect(s.completedBreaks == 4)
    let settled4 = s.setAbsent(.screenLock, false, at: epoch.addingTimeInterval(200))
    #expect(!settled4)
    #expect(s.completedBreaks == 4)
    #expect(s.phase == .working)
}

@Test func overlappingLockSleepAndSessionEventsCreditOneAbsence() {
    var s = schedulerBeforeLongBreak()
    s.startBreak()
    s.setAbsent(.screenLock, true, at: epoch)
    s.setAbsent(.screenLock, true, at: epoch.addingTimeInterval(20))
    s.setAbsent(.sleep, true, at: epoch.addingTimeInterval(30))
    s.setAbsent(.inactiveSession, true, at: epoch.addingTimeInterval(40))
    let settled5 = s.setAbsent(.sleep, false, at: epoch.addingTimeInterval(160))
    #expect(!settled5)
    let settled6 = s.setAbsent(.screenLock, false, at: epoch.addingTimeInterval(175))
    #expect(!settled6)
    #expect(s.isAway)
    let settled7 = s.setAbsent(.inactiveSession, false, at: epoch.addingTimeInterval(180))
    #expect(settled7)
    #expect(!s.isAway)
    #expect(s.workRemaining == 2700)
    #expect(!s.nextBreakIsLong)
}

@Test func lockUnderThresholdPreservesWorkAndLongBreakCycle() {
    var s = schedulerBeforeLongBreak()
    s.tick(100, idle: 0, pauseReasons: [])
    s.setAbsent(.screenLock, true, at: epoch)
    let settled8 = s.setAbsent(.screenLock, false, at: epoch.addingTimeInterval(179))
    #expect(!settled8)
    #expect(s.workRemaining == 2600)
    #expect(s.nextBreakIsLong)
}

@Test func interruptedBreakCannotReappearAfterCooldown() {
    var s = schedulerBeforeLongBreak()
    s.startBreak()
    s.tick(90, idle: 0, pauseReasons: [])
    s.tick(1, idle: 0, pauseReasons: ["remote"])
    s.tick(120, idle: 0, pauseReasons: ["remote"])
    s.tick(60, idle: 0, pauseReasons: [])
    #expect(s.phase == .working)
    #expect(s.workRemaining == 2640)
    #expect(s.completedBreaks == 3)
}

@Test func startingBreakTwiceDoesNotRestartCountdown() {
    var s = schedulerBeforeLongBreak()
    s.startBreak()
    s.tick(20, idle: 0, pauseReasons: [])
    s.startBreak()
    #expect(s.breakRemaining == 160)
    s.setAbsent(.screenLock, true, at: epoch)
    s.startBreak()
    #expect(s.breakRemaining == 160)
    #expect(MenuBarLabel(s, style: .countdown).symbol == "lock")
}
