import ABreakCore
import ServiceManagement
import SwiftUI

@MainActor
final class StatusModel: ObservableObject {
    @Published var reasons: [String] = []
    @Published var remoteSamples = ""
}

struct SettingsView: View {
    @ObservedObject var status: StatusModel

    @AppStorage(Pref.workMinutes) private var workMinutes = 45.0
    @AppStorage(Pref.breakSeconds) private var breakSeconds = 30.0
    @AppStorage(Pref.longBreakMinutes) private var longBreakMinutes = 3.0
    @AppStorage(Pref.longBreakEvery) private var longBreakEvery = 4
    @AppStorage(Pref.preBreakSeconds) private var preBreakSeconds = 10.0
    @AppStorage(Pref.idlePauseSeconds) private var idlePauseSeconds = 60.0
    @AppStorage(Pref.idleResetMinutes) private var idleResetMinutes = 5.0
    @AppStorage(Pref.resumeCooldownSeconds) private var resumeCooldownSeconds = 60.0

    @AppStorage(Pref.pauseOnRemoteControlled) private var pauseOnRemoteControlled = true
    @AppStorage(Pref.remoteHostProcesses) private var remoteHostProcesses = ""
    @AppStorage(Pref.pauseOnRemoteControlling) private var pauseOnRemoteControlling = true
    @AppStorage(Pref.remoteClientBundleIDs) private var remoteClientBundleIDs = ""
    @AppStorage(Pref.pauseOnMeeting) private var pauseOnMeeting = true
    @AppStorage(Pref.micIgnoredProcesses) private var micIgnoredProcesses = ""
    @AppStorage(Pref.pauseOnVideo) private var pauseOnVideo = true
    @AppStorage(Pref.videoIgnoredProcesses) private var videoIgnoredProcesses = ""
    @AppStorage(Pref.pauseOnFullscreen) private var pauseOnFullscreen = false
    @AppStorage(Pref.pauseApps) private var pauseApps = ""

    @AppStorage(Pref.playSounds) private var playSounds = true
    @AppStorage(Pref.allowSkip) private var allowSkip = true
    @AppStorage(Pref.postureEnabled) private var postureEnabled = true
    @AppStorage(Pref.postureMinutes) private var postureMinutes = 20.0
    @AppStorage(Pref.postureSize) private var postureSize = 2
    @AppStorage(Pref.posturePosition) private var posturePosition = 4
    @AppStorage(Pref.postureSound) private var postureSound = true
    @AppStorage(Pref.dimForReminders) private var dimForReminders = true
    @AppStorage(Pref.skipDelaySeconds) private var skipDelaySeconds = 3.0
    @AppStorage(Pref.menuBarTimerStyle) private var menuBarTimerStyle = MenuBarTimerStyle.countdown.rawValue
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private static let positions = ["Top Left", "Top", "Top Right", "Left", "Center", "Right", "Bottom Left", "Bottom", "Bottom Right"]

    var body: some View {
        Form {
            Section("Breaks") {
                Stepper("Break every \(Int(workMinutes)) min", value: $workMinutes, in: 1...120)
                Stepper("Short break: \(Int(breakSeconds)) s", value: $breakSeconds, in: 5...300, step: 5)
                Stepper(longBreakEvery == 0 ? "No long breaks" : "Long break every \(longBreakEvery) breaks", value: $longBreakEvery, in: 0...10)
                Stepper("Long break: \(Int(longBreakMinutes)) min", value: $longBreakMinutes, in: 1...30)
                    .disabled(longBreakEvery == 0)
                Stepper("Heads-up \(Int(preBreakSeconds)) s before a break", value: $preBreakSeconds, in: 0...60, step: 5)
                Toggle("Allow skipping breaks", isOn: $allowSkip)
                Stepper("Skip button enabled after \(Int(skipDelaySeconds)) s (double Esc skips anytime)", value: $skipDelaySeconds, in: 0...30)
                    .disabled(!allowSkip)
                Toggle("Play a sound when a break ends", isOn: $playSounds)
            }

            Section("Posture Reminder") {
                Toggle("Remind me to sit upright", isOn: $postureEnabled)
                Group {
                    Stepper("Every \(Int(postureMinutes)) min", value: $postureMinutes, in: 5...120, step: 5)
                    Picker("Size", selection: $postureSize) {
                        Text("Small").tag(0)
                        Text("Medium").tag(1)
                        Text("Large").tag(2)
                    }
                    Picker("Position", selection: $posturePosition) {
                        ForEach(Array(Self.positions.enumerated()), id: \.offset) { Text($0.element).tag($0.offset) }
                    }
                    Toggle("Dim the screen", isOn: $dimForReminders)
                    Toggle("Sound", isOn: $postureSound)
                }
                .disabled(!postureEnabled)
            }

            Section("Idle") {
                Stepper("Pause timer after \(Int(idlePauseSeconds)) s idle", value: $idlePauseSeconds, in: 10...600, step: 10)
                Stepper("Count \(Int(idleResetMinutes)) min idle as a break", value: $idleResetMinutes, in: 1...60)
            }

            Section {
                Toggle("This Mac is being remote-controlled", isOn: $pauseOnRemoteControlled)
                TextField("Remote host processes", text: $remoteHostProcesses, prompt: Text("UURemoteServer"))
                    .disabled(!pauseOnRemoteControlled)
                Toggle("Remote-controlling another device (client in front)", isOn: $pauseOnRemoteControlling)
                TextField("Remote client bundle IDs", text: $remoteClientBundleIDs, prompt: Text("com.netease.uuremote"))
                    .disabled(!pauseOnRemoteControlling)
                Toggle("Meetings and calls (microphone or camera in use)", isOn: $pauseOnMeeting)
                TextField("Ignored microphone processes", text: $micIgnoredProcesses, prompt: Text("Comma separated"))
                    .disabled(!pauseOnMeeting)
                Toggle("Video playback (display sleep is blocked)", isOn: $pauseOnVideo)
                TextField("Ignored processes", text: $videoIgnoredProcesses, prompt: Text("Comma separated"))
                    .disabled(!pauseOnVideo)
                Toggle("Fullscreen app in front", isOn: $pauseOnFullscreen)
                TextField("Pause while these apps are in front (bundle IDs)", text: $pauseApps, prompt: Text("com.apple.Keynote, ..."))
                Stepper("Wait at least \(Int(resumeCooldownSeconds)) s after a pause ends", value: $resumeCooldownSeconds, in: 0...600, step: 15)
            } header: {
                Text("Smart Pause")
            } footer: {
                Text("Any matching condition pauses the timer and dismisses a break in progress.")
                    .foregroundStyle(.secondary)
            }

            Section("Status") {
                if status.reasons.isEmpty {
                    Text("Not paused").foregroundStyle(.secondary)
                } else {
                    ForEach(status.reasons, id: \.self) { Text($0) }
                }
                Text(status.remoteSamples.isEmpty ? "No remote host process found" : status.remoteSamples)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Section("General") {
                Picker("Menu bar timer", selection: $menuBarTimerStyle) {
                    Text("Countdown (44:59)").tag(MenuBarTimerStyle.countdown.rawValue)
                    Text("Minutes (45m)").tag(MenuBarTimerStyle.minutes.rawValue)
                    Text("Icon only").tag(MenuBarTimerStyle.iconOnly.rawValue)
                }
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        do {
                            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {
                            Log.write("launch-at-login toggle failed: \(error)")
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 680)
    }
}
