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
    @AppStorage(Pref.language) private var language = AppLanguage.system.rawValue
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private var positions: [String] {
        [tr("Top Left", "左上"), tr("Top", "上方"), tr("Top Right", "右上"),
         tr("Left", "左侧"), tr("Center", "中央"), tr("Right", "右侧"),
         tr("Bottom Left", "左下"), tr("Bottom", "下方"), tr("Bottom Right", "右下")]
    }

    var body: some View {
        Form {
            Section {
                Picker(tr("Language", "语言"), selection: $language) {
                    Text(tr("Follow System", "跟随系统")).tag(AppLanguage.system.rawValue)
                    Text("English").tag(AppLanguage.english.rawValue)
                    Text("简体中文").tag(AppLanguage.chinese.rawValue)
                }
            }

            Section(tr("Breaks", "休息")) {
                Stepper(tr("Break every \(Int(workMinutes)) min", "每 \(Int(workMinutes)) 分钟休息一次"), value: $workMinutes, in: 1...120)
                Stepper(tr("Short break: \(Int(breakSeconds)) s", "短休息：\(Int(breakSeconds)) 秒"), value: $breakSeconds, in: 5...300, step: 5)
                Stepper(longBreakEvery == 0 ? tr("No long breaks", "不安排长休息") : tr("Long break every \(longBreakEvery) breaks", "每 \(longBreakEvery) 次休息安排一次长休息"), value: $longBreakEvery, in: 0...10)
                Stepper(tr("Long break: \(Int(longBreakMinutes)) min", "长休息：\(Int(longBreakMinutes)) 分钟"), value: $longBreakMinutes, in: 1...30)
                    .disabled(longBreakEvery == 0)
                Stepper(tr("Heads-up \(Int(preBreakSeconds)) s before a break", "休息前 \(Int(preBreakSeconds)) 秒提醒"), value: $preBreakSeconds, in: 0...60, step: 5)
                Toggle(tr("Allow skipping breaks", "允许跳过休息"), isOn: $allowSkip)
                Stepper(tr("Skip button enabled after \(Int(skipDelaySeconds)) s (double Esc skips anytime)", "跳过按钮 \(Int(skipDelaySeconds)) 秒后可用（连按两次 Esc 随时跳过）"), value: $skipDelaySeconds, in: 0...30)
                    .disabled(!allowSkip)
                Toggle(tr("Play a sound when a break ends", "休息结束时播放提示音"), isOn: $playSounds)
            }

            Section(tr("Posture Reminder", "坐姿提醒")) {
                Toggle(tr("Remind me to sit upright", "定时提醒坐直"), isOn: $postureEnabled)
                Group {
                    Stepper(tr("Every \(Int(postureMinutes)) min", "每 \(Int(postureMinutes)) 分钟一次"), value: $postureMinutes, in: 5...120, step: 5)
                    Picker(tr("Size", "大小"), selection: $postureSize) {
                        Text(tr("Small", "小")).tag(0)
                        Text(tr("Medium", "中")).tag(1)
                        Text(tr("Large", "大")).tag(2)
                    }
                    Picker(tr("Position", "位置"), selection: $posturePosition) {
                        ForEach(Array(positions.enumerated()), id: \.offset) { Text($0.element).tag($0.offset) }
                    }
                    Toggle(tr("Dim the screen", "提醒时调暗屏幕"), isOn: $dimForReminders)
                    Toggle(tr("Sound", "提示音"), isOn: $postureSound)
                }
                .disabled(!postureEnabled)
            }

            Section(tr("Idle", "离开检测")) {
                Stepper(tr("Pause timer after \(Int(idlePauseSeconds)) s idle", "无操作 \(Int(idlePauseSeconds)) 秒后暂停计时"), value: $idlePauseSeconds, in: 10...600, step: 10)
                Stepper(tr("Count \(Int(idleResetMinutes)) min idle as a break", "无操作 \(Int(idleResetMinutes)) 分钟视为已休息"), value: $idleResetMinutes, in: 1...60)
            }

            Section {
                Toggle(tr("This Mac is being remote-controlled", "本机被远程控制时"), isOn: $pauseOnRemoteControlled)
                TextField(tr("Remote host processes", "远程被控进程名"), text: $remoteHostProcesses, prompt: Text("UURemoteServer"))
                    .disabled(!pauseOnRemoteControlled)
                Toggle(tr("Remote-controlling another device (client in front)", "远程控制其他设备时（客户端在前台）"), isOn: $pauseOnRemoteControlling)
                TextField(tr("Remote client bundle IDs", "远程客户端 Bundle ID"), text: $remoteClientBundleIDs, prompt: Text("com.netease.uuremote"))
                    .disabled(!pauseOnRemoteControlling)
                Toggle(tr("Meetings and calls (microphone or camera in use)", "会议和通话（麦克风或摄像头在用）"), isOn: $pauseOnMeeting)
                TextField(tr("Ignored microphone processes", "忽略的麦克风进程"), text: $micIgnoredProcesses, prompt: Text(tr("Comma separated", "逗号分隔")))
                    .disabled(!pauseOnMeeting)
                Toggle(tr("Video playback (display sleep is blocked)", "视频播放（有进程阻止显示器休眠）"), isOn: $pauseOnVideo)
                TextField(tr("Ignored processes", "忽略的进程"), text: $videoIgnoredProcesses, prompt: Text(tr("Comma separated", "逗号分隔")))
                    .disabled(!pauseOnVideo)
                Toggle(tr("Fullscreen app in front", "前台应用全屏时"), isOn: $pauseOnFullscreen)
                TextField(tr("Pause while these apps are in front (bundle IDs)", "以下应用在前台时暂停（Bundle ID）"), text: $pauseApps, prompt: Text("com.apple.Keynote, ..."))
                Stepper(tr("Wait at least \(Int(resumeCooldownSeconds)) s after a pause ends", "暂停结束后至少再工作 \(Int(resumeCooldownSeconds)) 秒"), value: $resumeCooldownSeconds, in: 0...600, step: 15)
            } header: {
                Text(tr("Smart Pause", "智能暂停"))
            } footer: {
                Text(tr("Any matching condition pauses the timer and dismisses a break in progress.", "命中任一条件时暂停计时，并立即收起正在显示的休息。"))
                    .foregroundStyle(.secondary)
            }

            Section(tr("Status", "当前状态")) {
                if status.reasons.isEmpty {
                    Text(tr("Not paused", "未暂停")).foregroundStyle(.secondary)
                } else {
                    ForEach(status.reasons, id: \.self) { Text($0) }
                }
                Text(status.remoteSamples.isEmpty ? tr("No remote host process found", "未发现远程被控进程") : status.remoteSamples)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Section(tr("General", "通用")) {
                Picker(tr("Menu bar timer", "菜单栏计时"), selection: $menuBarTimerStyle) {
                    Text(tr("Countdown (44:59)", "倒计时（44:59）")).tag(MenuBarTimerStyle.countdown.rawValue)
                    Text(tr("Minutes (45m)", "分钟（45m）")).tag(MenuBarTimerStyle.minutes.rawValue)
                    Text(tr("Icon only", "仅图标")).tag(MenuBarTimerStyle.iconOnly.rawValue)
                }
                Toggle(tr("Launch at login", "登录时启动"), isOn: $launchAtLogin)
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
