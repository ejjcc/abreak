import AppKit
import CoreGraphics

/// `ABreak --probe`: prints raw detector signals every 2 seconds, for tuning detection thresholds.
enum Probe {
    @MainActor
    static func run() {
        Pref.register()
        let remote = RemoteSessionDetector(processNames: Pref.list(Pref.remoteHostProcesses))
        print("Watching remote host processes: \(remote.processNames.sorted()) (Ctrl-C to stop)")
        while true {
            let now = Date()
            let on = remote.poll(now: now)
            let samples = remote.lastSamples.map {
                "\($0.pid) \($0.name) tcp=\($0.tcpEstablished) udp=\($0.udpSockets) cpu=\(String(format: "%.1f", $0.cpuPercent))% disp=\($0.holdsDisplayAssertion ? "Y" : "n")"
            }.joined(separator: " | ")
            let mic = MediaDetectors.microphoneUsers().map(ProcessInspector.name(of:))
            let assertions = ProcessInspector.powerAssertionDetails()
            let video = MediaDetectors.videoPlaybackHolders(
                ignoring: Pref.list(Pref.videoIgnoredProcesses).union(Pref.list(Pref.remoteHostProcesses)),
                assertions: assertions
            )
            let displayActivities = assertions.flatMap { pid, activities in
                activities.filter(\.preventsDisplaySleep).map { "\(ProcessInspector.name(of: pid)): \($0.name)" }
            }.sorted()
            let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "-"
            print("""
            \(now.formatted(date: .omitted, time: .standard)) remote=\(on ? "ON " : "off") [\(samples)] \
            mic=\(mic) cam=\(MediaDetectors.isCameraInUse()) video=\(video) front=\(front) \
            fullscreen=\(MediaDetectors.frontmostIsFullscreen()) idle=\(Int(idleSeconds()))s displayActivities=\(displayActivities)
            """)
            fflush(stdout)
            Thread.sleep(forTimeInterval: 2)
        }
    }
}

func idleSeconds() -> TimeInterval {
    // kCGAnyInputEventType (~0); imported C enums accept any raw value.
    CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
}
