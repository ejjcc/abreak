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
    @AppStorage(Pref.breakSeconds) private var breakSeconds = 20.0
    @AppStorage(Pref.longBreakMinutes) private var longBreakMinutes = 5.0
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
    @AppStorage(Pref.pauseOnFullscreen) private var pauseOnFullscreen = true
    @AppStorage(Pref.pauseApps) private var pauseApps = ""

    @AppStorage(Pref.playSounds) private var playSounds = true
    @AppStorage(Pref.allowSkip) private var allowSkip = true
    @AppStorage(Pref.postureEnabled) private var postureEnabled = true
    @AppStorage(Pref.postureMinutes) private var postureMinutes = 20.0
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("计时") {
                Stepper("每工作 \(Int(workMinutes)) 分钟休息一次", value: $workMinutes, in: 1...120)
                Stepper("短休息 \(Int(breakSeconds)) 秒", value: $breakSeconds, in: 5...300, step: 5)
                Stepper(longBreakEvery == 0 ? "不安排长休息" : "每 \(longBreakEvery) 次短休息后一次长休息", value: $longBreakEvery, in: 0...10)
                Stepper("长休息 \(Int(longBreakMinutes)) 分钟", value: $longBreakMinutes, in: 1...30)
                    .disabled(longBreakEvery == 0)
                Stepper("提前 \(Int(preBreakSeconds)) 秒提醒", value: $preBreakSeconds, in: 0...60, step: 5)
                Toggle("允许跳过休息", isOn: $allowSkip)
                Toggle("休息结束时播放提示音", isOn: $playSounds)
            }

            Section("坐姿提醒") {
                Toggle("定时提醒调整坐姿", isOn: $postureEnabled)
                Stepper("每 \(Int(postureMinutes)) 分钟一次", value: $postureMinutes, in: 5...120, step: 5)
                    .disabled(!postureEnabled)
            }

            Section("离开检测") {
                Stepper("无操作 \(Int(idlePauseSeconds)) 秒后暂停计时", value: $idlePauseSeconds, in: 10...600, step: 10)
                Stepper("无操作 \(Int(idleResetMinutes)) 分钟视为已休息", value: $idleResetMinutes, in: 1...60)
            }

            Section {
                Toggle("本机被远程控制时", isOn: $pauseOnRemoteControlled)
                TextField("远程被控进程名", text: $remoteHostProcesses, prompt: Text("UURemoteServer"))
                    .disabled(!pauseOnRemoteControlled)
                Toggle("用本机远程控制其他设备时（客户端在前台）", isOn: $pauseOnRemoteControlling)
                TextField("远程客户端 Bundle ID", text: $remoteClientBundleIDs, prompt: Text("com.netease.uuremote"))
                    .disabled(!pauseOnRemoteControlling)
                Toggle("会议/通话时（麦克风或摄像头在用）", isOn: $pauseOnMeeting)
                TextField("忽略的麦克风进程", text: $micIgnoredProcesses, prompt: Text("逗号分隔"))
                    .disabled(!pauseOnMeeting)
                Toggle("播放视频时（有进程阻止显示器休眠）", isOn: $pauseOnVideo)
                TextField("忽略的进程", text: $videoIgnoredProcesses, prompt: Text("逗号分隔"))
                    .disabled(!pauseOnVideo)
                Toggle("前台应用全屏时", isOn: $pauseOnFullscreen)
                TextField("以下应用在前台时暂停（Bundle ID）", text: $pauseApps, prompt: Text("com.apple.Keynote, ..."))
                Stepper("暂停结束后至少再工作 \(Int(resumeCooldownSeconds)) 秒", value: $resumeCooldownSeconds, in: 0...600, step: 15)
            } header: {
                Text("免打扰（智能暂停）")
            } footer: {
                Text("命中任一条件时暂停计时；正在显示的休息会立即收起。")
                    .foregroundStyle(.secondary)
            }

            Section("当前状态") {
                if status.reasons.isEmpty {
                    Text("未暂停").foregroundStyle(.secondary)
                } else {
                    ForEach(status.reasons, id: \.self) { Text($0) }
                }
                Text(status.remoteSamples.isEmpty ? "未发现远程被控进程" : status.remoteSamples)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Section("通用") {
                Toggle("登录时启动", isOn: $launchAtLogin)
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
