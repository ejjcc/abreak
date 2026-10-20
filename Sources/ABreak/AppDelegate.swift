import AppKit
import ABreakCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var scheduler = Scheduler()
    private let monitor = PauseMonitor()
    private let overlay = BreakOverlay()
    private let preBreak = PreBreakPanel()
    private let postureReminder = PostureReminder()
    private var posture = IntervalReminder(interval: 0)
    private let status = StatusModel()
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var timer: Timer?
    private var lastTick = Date()
    private var sleptAt: Date?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Pref.register()
        scheduler.config = Pref.schedulerConfig
        scheduler.resetWork()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu

        overlay.model.onSkip = { [weak self] in self?.act { $0.skipBreak() } }
        preBreak.model.onStart = { [weak self] in self?.act { $0.startBreak() } }
        preBreak.model.onPostpone = { [weak self] in self?.act { $0.postpone(5 * 60) } }
        preBreak.model.onSkip = { [weak self] in self?.act { $0.skipBreak() } }

        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sleptAt = Date() }
        }
        center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.didWake() }
        }

        Log.write("launched")
        render()
        // `--preview posture|break`: show a component right away, for visual checks.
        if let i = CommandLine.arguments.firstIndex(of: "--preview"), i + 1 < CommandLine.arguments.count {
            switch CommandLine.arguments[i + 1] {
            case "posture": postureReminder.show()
            case "break": act { $0.startBreak() }
            default: break
            }
        }
        // Common modes keep the timer running while the status menu is open.
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // MARK: - Loop

    private func tick() {
        let now = Date()
        let dt = min(max(now.timeIntervalSince(lastTick), 0), 5)
        lastTick = now

        let config = Pref.schedulerConfig
        if config != scheduler.config { scheduler.config = config }

        let reasons = monitor.reasons(now: now)
        let before = scheduler
        scheduler.tick(dt, idle: idleSeconds(), pauseReasons: reasons)
        if reasons != before.pauseReasons {
            Log.write("pause reasons: \(reasons.isEmpty ? "none" : reasons.joined(separator: "; ")) | remote: \(remoteSummary())")
        }
        transition(from: before)

        posture.interval = Pref.bool(Pref.postureEnabled) ? max(5, Pref.double(Pref.postureMinutes)) * 60 : 0
        let working = scheduler.phase == .working && !scheduler.isPaused && !scheduler.isIdle
        if posture.tick(dt, active: working) {
            postureReminder.show()
            Log.write("posture reminder")
        }
    }

    private func act(_ change: (inout Scheduler) -> Void) {
        let before = scheduler
        change(&scheduler)
        transition(from: before)
    }

    private func transition(from before: Scheduler) {
        if before.phase != scheduler.phase {
            Log.write("phase: \(before.phase) -> \(scheduler.phase)")
            if case .onBreak = before.phase, scheduler.phase == .working,
               scheduler.completedBreaks > before.completedBreaks {
                posture.reset()
                if Pref.bool(Pref.playSounds) { NSSound(named: "Glass")?.play() }
            }
        }

        switch scheduler.phase {
        case .working:
            preBreak.hide()
            if overlay.isVisible { overlay.hide(animated: scheduler.completedBreaks > before.completedBreaks) }
        case .preBreak:
            preBreak.show(remaining: scheduler.workRemaining)
            preBreak.update(remaining: scheduler.workRemaining)
        case .onBreak(let long):
            preBreak.hide()
            if !overlay.isVisible { overlay.show(long: long, duration: scheduler.breakRemaining) }
            overlay.update(remaining: scheduler.breakRemaining)
        }
        render()
    }

    private func didWake() {
        lastTick = Date()
        if let slept = sleptAt, Date().timeIntervalSince(slept) >= scheduler.config.idleResetAfter {
            act { $0.resetWork() }
        }
        sleptAt = nil
    }

    // MARK: - Menu bar

    private func render() {
        guard let button = statusItem.button else { return }
        let symbol: String
        let title: String
        switch scheduler.phase {
        case _ where scheduler.isPaused:
            symbol = "pause.circle"
            title = ""
        case .onBreak:
            symbol = "eye.slash"
            title = " " + DurationFormat.compact(scheduler.breakRemaining)
        default:
            symbol = scheduler.isIdle ? "moon.zzz" : "eye"
            title = " " + DurationFormat.compact(scheduler.workRemaining)
        }
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "ABreak")
        button.title = title
        button.toolTip = scheduler.isPaused ? scheduler.pauseReasons.joined(separator: "\n") : nil

        status.reasons = scheduler.pauseReasons
        status.remoteSamples = remoteSummary()
    }

    private func remoteSummary() -> String {
        monitor.remote.lastSamples.map {
            "\($0.name)[\($0.pid)] tcp=\($0.tcpEstablished) udp=\($0.udpSockets) cpu=\(String(format: "%.1f", $0.cpuPercent))%"
        }.joined(separator: "\n")
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let header: String
        if scheduler.isPaused {
            header = "Paused"
        } else if case .onBreak = scheduler.phase {
            header = "On break, \(DurationFormat.clock(scheduler.breakRemaining)) left"
        } else {
            header = "\(scheduler.nextBreakIsLong ? "Long break" : "Break") in \(DurationFormat.clock(scheduler.workRemaining))" + (scheduler.isIdle ? " (away)" : "")
        }
        menu.addItem(disabled(header))
        for reason in scheduler.pauseReasons {
            menu.addItem(disabled("  · " + reason))
        }
        menu.addItem(.separator())

        let breakNow = item("Take a Break Now") { $0.act { $0.startBreak() } }
        breakNow.isEnabled = !scheduler.isPaused
        menu.addItem(breakNow)
        menu.addItem(item("Restart Timer") { $0.act { $0.resetWork() } })

        let pause = NSMenuItem(title: "Pause", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for (label, minutes) in [("For 30 Minutes", 30.0), ("For 1 Hour", 60), ("For 2 Hours", 120)] {
            sub.addItem(item(label) { $0.pauseManually(until: Date().addingTimeInterval(minutes * 60)) })
        }
        sub.addItem(item("Until Tomorrow") {
            $0.pauseManually(until: Calendar.current.startOfDay(for: Date().addingTimeInterval(86400)))
        })
        sub.addItem(item("Until I Resume") { $0.pauseManually(until: .distantFuture) })
        pause.submenu = sub
        menu.addItem(pause)
        if monitor.manualUntil != nil {
            menu.addItem(item("Resume") { $0.pauseManually(until: nil) })
        }

        menu.addItem(item("Preview Posture Reminder") { $0.postureReminder.show() })

        menu.addItem(.separator())
        menu.addItem(item("Settings…", key: ",") { $0.openSettings() })
        menu.addItem(item("Open Log") { _ in
            NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/ABreak.log"))
        })
        menu.addItem(item("Quit ABreak", key: "q") { _ in NSApp.terminate(nil) })
    }

    private func pauseManually(until: Date?) {
        monitor.manualUntil = until
        tick()
    }

    private func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(status: status)))
            w.title = "ABreak Settings"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        i.isEnabled = false
        return i
    }

    private func item(_ title: String, key: String = "", _ handler: @escaping (AppDelegate) -> Void) -> NSMenuItem {
        let i = ClosureMenuItem(title: title, keyEquivalent: key) { [weak self] in
            if let self { handler(self) }
        }
        return i
    }
}

private final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, keyEquivalent: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: keyEquivalent)
        target = self
    }

    required init(coder: NSCoder) { fatalError() }

    @objc private func fire() { handler() }
}
