import AppKit

MainActor.assumeIsolated {
    if CommandLine.arguments.contains("--probe") {
        Probe.run()
    }
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
