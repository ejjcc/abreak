import Foundation
import ABreakCore

enum Pref {
    static let workMinutes = "workMinutes"
    static let breakSeconds = "breakSeconds"
    static let longBreakMinutes = "longBreakMinutes"
    static let longBreakEvery = "longBreakEvery"
    static let preBreakSeconds = "preBreakSeconds"
    static let idlePauseSeconds = "idlePauseSeconds"
    static let idleResetMinutes = "idleResetMinutes"
    static let resumeCooldownSeconds = "resumeCooldownSeconds"

    static let pauseOnRemoteControlled = "pauseOnRemoteControlled"
    static let remoteHostProcesses = "remoteHostProcesses"
    static let pauseOnRemoteControlling = "pauseOnRemoteControlling"
    static let remoteClientBundleIDs = "remoteClientBundleIDs"
    static let pauseOnMeeting = "pauseOnMeeting"
    static let micIgnoredProcesses = "micIgnoredProcesses"
    static let pauseOnVideo = "pauseOnVideo"
    static let videoIgnoredProcesses = "videoIgnoredProcesses"
    static let pauseOnFullscreen = "pauseOnFullscreen"
    static let pauseApps = "pauseApps"

    static let playSounds = "playSounds"
    static let allowSkip = "allowSkip"
    static let postureEnabled = "postureEnabled"
    static let postureMinutes = "postureMinutes"
    static let postureSize = "postureSize"
    static let posturePosition = "posturePosition"
    static let postureSound = "postureSound"
    static let dimForReminders = "dimForReminders"
    static let skipDelaySeconds = "skipDelaySeconds"
    static let menuBarTimerStyle = "menuBarTimerStyle"

    /// Defaults mirror the owner's LookAway setup: 45-min focus, 30-s short / 3-min long breaks,
    /// fullscreen pause off (LookAway has none; fullscreen video is covered by video detection),
    /// pause on meetings and video, posture every 20 min at large size in the screen center.
    static func register() {
        UserDefaults.standard.register(defaults: [
            workMinutes: 45,
            breakSeconds: 30,
            longBreakMinutes: 3,
            longBreakEvery: 4,
            preBreakSeconds: 10,
            idlePauseSeconds: 60,
            idleResetMinutes: 5,
            resumeCooldownSeconds: 60,
            pauseOnRemoteControlled: true,
            remoteHostProcesses: "UURemoteServer",
            pauseOnRemoteControlling: true,
            remoteClientBundleIDs: "com.netease.uuremote",
            pauseOnMeeting: true,
            micIgnoredProcesses: "",
            pauseOnVideo: true,
            videoIgnoredProcesses: "caffeinate, Amphetamine, KeepingYouAwake, Lungo",
            pauseOnFullscreen: false,
            pauseApps: "",
            playSounds: true,
            allowSkip: true,
            postureEnabled: true,
            postureMinutes: 20,
            postureSize: 2,
            posturePosition: 4,
            postureSound: true,
            dimForReminders: true,
            skipDelaySeconds: 3,
            menuBarTimerStyle: MenuBarTimerStyle.countdown.rawValue,
        ])
    }

    static func bool(_ key: String) -> Bool { UserDefaults.standard.bool(forKey: key) }
    static func double(_ key: String) -> Double { UserDefaults.standard.double(forKey: key) }

    /// Comma/newline separated list setting.
    static func list(_ key: String) -> Set<String> {
        let raw = UserDefaults.standard.string(forKey: key) ?? ""
        return Set(raw.split(whereSeparator: { $0 == "," || $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty })
    }

    static var schedulerConfig: SchedulerConfig {
        var c = SchedulerConfig()
        c.workInterval = max(1, double(workMinutes)) * 60
        c.shortBreak = max(5, double(breakSeconds))
        c.longBreak = max(1, double(longBreakMinutes)) * 60
        c.longBreakEvery = max(0, UserDefaults.standard.integer(forKey: longBreakEvery))
        c.preBreakWarning = max(0, double(preBreakSeconds))
        c.idlePauseAfter = max(10, double(idlePauseSeconds))
        c.idleResetAfter = max(1, double(idleResetMinutes)) * 60
        c.resumeCooldown = max(0, double(resumeCooldownSeconds))
        return c
    }
}
