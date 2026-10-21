import Testing
@testable import ABreakCore

@Test(arguments: ["Capturing", "Screen Wake Lock", "UniversalControl", "Electron", "", "Playing audio"])
func nonVideoActivitiesDoNotPause(_ name: String) {
    let assertion = PowerAssertion(type: "NoDisplaySleepAssertion", name: name, isActive: true)
    #expect(assertion.preventsDisplaySleep)
    #expect(!assertion.isVideoPlayback)
}

@Test(arguments: ["Video Wake Lock", "Playing video", "com.apple.WebCore: HTMLMediaElement playback", "VLC media playback"])
func playbackRequiresActiveDisplayAssertion(_ name: String) {
    #expect(PowerAssertion(type: "NoDisplaySleepAssertion", name: name, isActive: true).isVideoPlayback)
    #expect(PowerAssertion(type: "PreventUserIdleDisplaySleep", name: name, isActive: true).isVideoPlayback)
    #expect(!PowerAssertion(type: "NoDisplaySleepAssertion", name: name, isActive: false).isVideoPlayback)
    #expect(!PowerAssertion(type: "PreventUserIdleSystemSleep", name: name, isActive: true).isVideoPlayback)
}

@Test func browserCaptureDoesNotMaskPlaybackOrPreventResuming() {
    let capture = PowerAssertion(type: "NoDisplaySleepAssertion", name: "Capturing", isActive: true)
    var video = PowerAssertion(type: "NoDisplaySleepAssertion", name: "Video Wake Lock", isActive: true)
    var config = SchedulerConfig()
    config.workInterval = 60
    config.resumeCooldown = 0
    var scheduler = Scheduler(config: config)

    func reasons(_ assertions: [PowerAssertion]) -> [String] {
        assertions.contains(where: \.isVideoPlayback) ? ["Video playing (browser)"] : []
    }
    scheduler.tick(1, idle: 0, pauseReasons: reasons([capture]))
    #expect(!scheduler.isPaused)
    let remaining = scheduler.workRemaining

    scheduler.tick(1, idle: 0, pauseReasons: reasons([capture, video]))
    #expect(scheduler.isPaused)
    #expect(scheduler.workRemaining == remaining)

    video.isActive = false
    scheduler.tick(1, idle: 0, pauseReasons: reasons([capture, video]))
    scheduler.tick(1, idle: 0, pauseReasons: reasons([capture]))
    #expect(!scheduler.isPaused)
    #expect(scheduler.workRemaining < remaining)
}
