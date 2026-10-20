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
                result.append(until == .distantFuture
                    ? tr("Paused manually", "手动暂停")
                    : tr("Paused until \(until.formatted(date: .omitted, time: .shortened))", "暂停至 \(until.formatted(date: .omitted, time: .shortened))"))
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
            result.append(tr("Remote-controlling another device (\(frontName))", "正在远程控制其他设备（\(frontName)）"))
        }
        if Pref.list(Pref.pauseApps).contains(frontID) {
            result.append(tr("Pause app in front (\(frontName))", "指定应用在前台（\(frontName)）"))
        }
        if Pref.bool(Pref.pauseOnFullscreen), MediaDetectors.frontmostIsFullscreen() {
            result.append(tr("Fullscreen app (\(frontName))", "全屏应用（\(frontName)）"))
        }
        return result
    }

    private func probe(now: Date) -> [String] {
        var result: [String] = []

        if Pref.bool(Pref.pauseOnRemoteControlled) {
            remote.processNames = Pref.list(Pref.remoteHostProcesses)
            if remote.poll(now: now) {
                let names = Set(remote.lastSamples.filter(remote.rule.isActive).map(\.name)).sorted()
                let who = names.isEmpty ? tr("holding", "保持中") : names.joined(separator: ", ")
                result.append(tr("Being remote-controlled (\(who))", "本机被远程控制中（\(who)）"))
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
                let users = Set(mic).sorted().joined(separator: ", ")
                result.append(tr("Microphone in use (\(users))", "麦克风使用中（\(users)）"))
            } else if MediaDetectors.isCameraInUse() {
                result.append(tr("Camera in use", "摄像头使用中"))
            }
        }

        if Pref.bool(Pref.pauseOnVideo) {
            // Remote hosts keep the display awake during a session; that is the remote rule's job, not video.
            let holders = MediaDetectors.displaySleepHolders(
                ignoring: Pref.list(Pref.videoIgnoredProcesses).union(Pref.list(Pref.remoteHostProcesses)),
                assertions: ProcessInspector.powerAssertions()
            )
            if !holders.isEmpty {
                let players = Set(holders).sorted().joined(separator: ", ")
                result.append(tr("Video playing (\(players))", "视频播放中（\(players)）"))
            }
        }
        return result
    }
}
