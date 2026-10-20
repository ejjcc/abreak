import AppKit
import ABreakCore

/// Aggregates every smart-pause source into a list of human-readable reasons.
@MainActor
final class PauseMonitor {
    let remote = RemoteSessionDetector(processNames: [])
    var manualUntil: Date?

    private var tickCount = 0
    private var probed: [String] = []

    func reasons(now: Date = Date()) -> [String] {
        var result: [String] = []

        if let until = manualUntil {
            if until > now {
                result.append(until == .distantFuture ? "Paused manually" : "Paused until \(until.formatted(date: .omitted, time: .shortened))")
            } else {
                manualUntil = nil
            }
        }

        // Process/audio probes cost a few ms; run them every other second.
        if tickCount % 2 == 0 { probed = probe(now: now) }
        tickCount += 1
        result += probed

        let front = NSWorkspace.shared.frontmostApplication
        let frontID = front?.bundleIdentifier ?? ""
        let frontName = front?.localizedName ?? frontID
        if Pref.bool(Pref.pauseOnRemoteControlling), Pref.list(Pref.remoteClientBundleIDs).contains(frontID) {
            result.append("Remote-controlling another device (\(frontName))")
        }
        if Pref.list(Pref.pauseApps).contains(frontID) {
            result.append("Pause app in front (\(frontName))")
        }
        if Pref.bool(Pref.pauseOnFullscreen), MediaDetectors.frontmostIsFullscreen() {
            result.append("Fullscreen app (\(frontName))")
        }
        return result
    }

    private func probe(now: Date) -> [String] {
        var result: [String] = []

        if Pref.bool(Pref.pauseOnRemoteControlled) {
            remote.processNames = Pref.list(Pref.remoteHostProcesses)
            if remote.poll(now: now) {
                let names = Set(remote.lastSamples.filter(remote.rule.isActive).map(\.name)).sorted()
                result.append("Being remote-controlled (\(names.isEmpty ? "holding" : names.joined(separator: ", ")))")
            }
        }

        if Pref.bool(Pref.pauseOnMeeting) {
            let ignored = Pref.list(Pref.micIgnoredProcesses)
            let me = getpid()
            let mic = MediaDetectors.microphoneUsers()
                .filter { $0 != me }
                .map(ProcessInspector.name(of:))
                .filter { !ignored.contains($0) }
            if !mic.isEmpty {
                result.append("Microphone in use (\(Set(mic).sorted().joined(separator: ", ")))")
            } else if MediaDetectors.isCameraInUse() {
                result.append("Camera in use")
            }
        }

        if Pref.bool(Pref.pauseOnVideo) {
            let holders = MediaDetectors.displaySleepHolders(
                ignoring: Pref.list(Pref.videoIgnoredProcesses),
                assertions: ProcessInspector.powerAssertions()
            )
            if !holders.isEmpty {
                result.append("Video playing (\(Set(holders).sorted().joined(separator: ", ")))")
            }
        }
        return result
    }
}
