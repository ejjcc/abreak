import Foundation
import Testing
@testable import ABreakCore

private func config() -> SchedulerConfig {
    var c = SchedulerConfig()
    c.workInterval = 100
    c.shortBreak = 10
    c.longBreak = 30
    c.longBreakEvery = 2
    c.preBreakWarning = 5
    c.idlePauseAfter = 60
    c.idleResetAfter = 300
    c.resumeCooldown = 20
    return c
}

private extension Scheduler {
    mutating func run(_ seconds: Int, idle: TimeInterval = 0, reasons: [String] = []) {
        for _ in 0..<seconds { tick(1, idle: idle, pauseReasons: reasons) }
    }
}

@Test func workCountdownEntersPreBreakThenBreak() {
    var s = Scheduler(config: config())
    s.run(94)
    #expect(s.phase == .working)
    s.run(1)
    #expect(s.phase == .preBreak)
    s.run(5)
    #expect(s.phase == .onBreak(long: false))
    s.run(10)
    #expect(s.phase == .working)
    #expect(s.completedBreaks == 1)
    #expect(s.workRemaining == 100)
}

@Test func everyNthBreakIsLong() {
    var s = Scheduler(config: config())
    s.run(100 + 10)
    s.run(100)
    #expect(s.phase == .onBreak(long: true))
    #expect(s.breakRemaining == 30)
}

@Test func idleFreezesThenResets() {
    var s = Scheduler(config: config())
    s.run(10)
    s.run(10, idle: 120)
    #expect(s.workRemaining == 90)
    #expect(s.isIdle)
    s.run(1, idle: 300)
    #expect(s.workRemaining == 100)
}

@Test func idleDoesNotStopRunningBreak() {
    var s = Scheduler(config: config())
    s.startBreak()
    s.run(10, idle: 400)
    #expect(s.phase == .working)
    #expect(s.completedBreaks == 1)
}

@Test func smartPauseCancelsBreakAndAppliesCooldown() {
    var s = Scheduler(config: config())
    s.run(100)
    #expect(s.phase == .onBreak(long: false))
    s.run(30, reasons: ["remote"])
    #expect(s.phase == .working)
    #expect(s.isPaused)
    #expect(s.completedBreaks == 0)
    s.run(1)
    #expect(!s.isPaused)
    #expect(s.workRemaining == 19)
}

@Test func smartPauseFreezesWorkCountdown() {
    var s = Scheduler(config: config())
    s.run(30)
    s.run(50, reasons: ["meeting"])
    s.run(1)
    #expect(s.workRemaining == 69)
}

@Test func postponeAndSkip() {
    var s = Scheduler(config: config())
    s.startBreak()
    s.postpone(60)
    #expect(s.phase == .working)
    #expect(s.workRemaining == 60)
    s.startBreak()
    s.skipBreak()
    #expect(s.workRemaining == 100)
    #expect(s.completedBreaks == 0)
}

@Test func shrinkingWorkIntervalClampsRemaining() {
    var s = Scheduler(config: config())
    s.config.workInterval = 50
    #expect(s.workRemaining == 50)
}

@Test func latchNeedsConsecutiveHitsAndHoldsOff() {
    var l = ActivityLatch(onAfter: 2, offAfter: 20)
    let t0 = Date(timeIntervalSince1970: 0)
    let steps: [(Bool, TimeInterval, Bool)] = [
        (true, 0, false), (false, 2, false), (true, 4, false),
        (true, 6, true), (false, 20, true), (false, 26, false),
    ]
    for (input, offset, expected) in steps {
        let on = l.update(input, at: t0 + offset)
        #expect(on == expected, "t+\(offset)")
    }
}

@Test func remoteEvidenceRule() {
    let rule = RemoteEvidenceRule()
    let idle = RemoteProcessSample(pid: 1, name: "UURemoteServer", tcpEstablished: 1, udpSockets: 0, cpuPercent: 0.1, holdsDisplayAssertion: false)
    #expect(!rule.isActive(idle))
    var udp = idle; udp.udpSockets = 2
    #expect(rule.isActive(udp))
    var busy = idle; busy.cpuPercent = 12
    #expect(rule.isActive(busy))
}

@Test func intervalReminderCountsOnlyActiveTime() {
    var r = IntervalReminder(interval: 10)
    var fired = 0
    for i in 0..<30 where r.tick(1, active: i % 2 == 0) { fired += 1 }
    #expect(fired == 1)
    #expect(r.elapsed == 5)
    r.reset()
    #expect(r.elapsed == 0)
}

@Test func startBreakIsIgnoredWhilePaused() {
    var s = Scheduler(config: config())
    s.run(1, reasons: ["manual"])
    s.startBreak()
    #expect(s.phase == .working)
}

@Test func loweringPreBreakWarningLeavesPreBreak() {
    var s = Scheduler(config: config())
    s.run(96)
    #expect(s.phase == .preBreak)
    s.config.preBreakWarning = 0
    s.run(1)
    #expect(s.phase == .working)
}

@Test func durationFormats() {
    #expect(DurationFormat.compact(45 * 60) == "45m")
    #expect(DurationFormat.compact(44 * 60 + 1) == "45m")
    #expect(DurationFormat.compact(60) == "1m")
    #expect(DurationFormat.compact(59) == "59s")
    #expect(DurationFormat.compact(0) == "0s")
    #expect(DurationFormat.clock(27) == "00:27")
    #expect(DurationFormat.clock(176.4) == "02:57")
}

@Test func doublePressWithinWindow() {
    var d = DoublePress(window: 1)
    let t0 = Date(timeIntervalSince1970: 0)
    let fired = [0, 0.4, 0.6, 2, 2.9].map { d.press(at: t0 + $0) }
    #expect(fired == [false, true, false, false, true])
}

@Test func menuBarLabelShowsCountdownInEveryState() {
    var s = Scheduler(config: config())
    s.run(1)
    #expect(MenuBarLabel(s, style: .countdown) == MenuBarLabel(symbol: "eye", text: "01:39", dimmed: false))
    #expect(MenuBarLabel(s, style: .minutes).text == "2m")
    #expect(MenuBarLabel(s, style: .iconOnly).text == "")

    // Paused: time is kept and frozen, icon explains why it is not moving.
    s.run(30, reasons: ["Being remote-controlled"])
    #expect(MenuBarLabel(s, style: .countdown) == MenuBarLabel(symbol: "pause.circle", text: "01:39", dimmed: true))

    // Resumes counting from the frozen value.
    s.run(2)
    #expect(MenuBarLabel(s, style: .countdown) == MenuBarLabel(symbol: "eye", text: "01:37", dimmed: false))

    s.startBreak()
    s.run(3)
    #expect(MenuBarLabel(s, style: .countdown) == MenuBarLabel(symbol: "eye.slash", text: "00:07", dimmed: false))

    var idle = Scheduler(config: config())
    idle.run(5, idle: 120)
    #expect(MenuBarLabel(idle, style: .countdown) == MenuBarLabel(symbol: "moon.zzz", text: "01:40", dimmed: true))
}

@Test func languageResolution() {
    #expect(AppLanguage.system.resolved(preferredLanguages: ["zh-Hans-CN", "en-US"]) == .chinese)
    #expect(AppLanguage.system.resolved(preferredLanguages: ["zh-Hant-TW"]) == .chinese)
    #expect(AppLanguage.system.resolved(preferredLanguages: ["en-US", "zh-Hans-CN"]) == .english)
    #expect(AppLanguage.system.resolved(preferredLanguages: ["ja-JP"]) == .english)
    #expect(AppLanguage.system.resolved(preferredLanguages: []) == .english)
    #expect(AppLanguage.english.resolved(preferredLanguages: ["zh-Hans-CN"]) == .english)
    #expect(AppLanguage.chinese.resolved(preferredLanguages: ["en-US"]) == .chinese)
}
