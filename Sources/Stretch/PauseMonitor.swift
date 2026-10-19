import AppKit
import StretchCore

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
                result.append(until == .distantFuture ? "手动暂停" : "手动暂停至 \(until.formatted(date: .omitted, time: .shortened))")
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
            result.append("正在远程控制其他设备（\(frontName)）")
        }
        if Pref.list(Pref.pauseApps).contains(frontID) {
            result.append("指定应用在前台（\(frontName)）")
        }
        if Pref.bool(Pref.pauseOnFullscreen), MediaDetectors.frontmostIsFullscreen() {
            result.append("全屏应用（\(frontName)）")
        }
        return result
    }

    private func probe(now: Date) -> [String] {
        var result: [String] = []

        if Pref.bool(Pref.pauseOnRemoteControlled) {
            remote.processNames = Pref.list(Pref.remoteHostProcesses)
            if remote.poll(now: now) {
                let names = Set(remote.lastSamples.filter(remote.rule.isActive).map(\.name)).sorted()
                result.append("本机被远程控制中（\(names.isEmpty ? "保持中" : names.joined(separator: ", "))）")
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
                result.append("麦克风使用中（\(Set(mic).sorted().joined(separator: ", "))）")
            } else if MediaDetectors.isCameraInUse() {
                result.append("摄像头使用中")
            }
        }

        if Pref.bool(Pref.pauseOnVideo) {
            let holders = MediaDetectors.displaySleepHolders(
                ignoring: Pref.list(Pref.videoIgnoredProcesses),
                assertions: ProcessInspector.powerAssertions()
            )
            if !holders.isEmpty {
                result.append("视频播放中（\(Set(holders).sorted().joined(separator: ", "))）")
            }
        }
        return result
    }
}
