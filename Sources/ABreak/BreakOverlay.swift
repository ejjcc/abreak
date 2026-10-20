import ABreakCore
import AppKit
import SwiftUI

@MainActor
final class BreakModel: ObservableObject {
    @Published var remaining: TimeInterval = 0
    @Published var total: TimeInterval = 1
    @Published var long = false
    @Published var allowSkip = true
    @Published var skipDelay: TimeInterval = 10
    var onSkip: () -> Void = {}

    var canSkip: Bool { allowSkip && total - remaining >= skipDelay }
    var skipWait: Int { max(1, Int((skipDelay - (total - remaining)).rounded(.up))) }

    func lockScreen() {
        ScreenLock.lock()
    }
}

/// Full-screen break cover on every display.
@MainActor
final class BreakOverlay {
    let model = BreakModel()
    private var windows: [NSWindow] = []

    var isVisible: Bool { !windows.isEmpty }

    func show(long: Bool, duration: TimeInterval) {
        model.long = long
        model.total = duration
        model.remaining = duration
        model.allowSkip = Pref.bool(Pref.allowSkip)
        model.skipDelay = max(0, Pref.double(Pref.skipDelaySeconds))
        guard windows.isEmpty else { return }

        for screen in NSScreen.screens {
            let window = OverlayWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.setFrame(screen.frame, display: false)
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.isOpaque = false
            window.backgroundColor = .clear
            window.isReleasedWhenClosed = false
            // Double Esc is a deliberate gesture, so it skips immediately without the button's delay.
            window.onDoubleEscape = { [weak self] in
                if self?.model.allowSkip == true { self?.model.onSkip() }
            }
            window.contentView = NSHostingView(rootView: BreakView(model: model))
            window.alphaValue = 0
            window.orderFrontRegardless()
            windows.append(window)
        }
        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKey()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.6
            windows.forEach { $0.animator().alphaValue = 1 }
        }
    }

    func update(remaining: TimeInterval) {
        model.remaining = max(0, remaining)
    }

    /// Fades out after a completed break; closes instantly when skipped or cancelled so nothing lingers.
    func hide(animated: Bool) {
        let closing = windows
        windows = []
        guard animated else {
            closing.forEach { $0.orderOut(nil) }
            return
        }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.4
            closing.forEach { $0.animator().alphaValue = 0 }
        }, completionHandler: {
            closing.forEach { $0.orderOut(nil) }
        })
    }
}

private final class OverlayWindow: NSWindow {
    var onDoubleEscape: () -> Void = {}
    private var escape = DoublePress()

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard event.keyCode == 53 else { return }
        if escape.press(at: Date()) { onDoubleEscape() }
    }
}

private struct BreakView: View {
    @ObservedObject var model: BreakModel

    /// Vertical centers as fractions of screen height, measured from LookAway frames (3024x1964 @2x).
    private enum Y {
        static let clock = 0.084
        static let buttons = 0.893
        static let hint = 0.937
        static let short = (title: 0.3764, subtitle: 0.450, divider: 0.504, countdown: 0.570)
        static let long = (tag: 0.330, title: 0.4064, subtitle: 0.479, divider: 0.533, countdown: 0.599)
    }

    /// Background gray levels sampled top to bottom at 0, 25, 50, 75, 100% height.
    private var background: LinearGradient {
        let levels: [Double] = model.long ? [16, 12, 8, 4, 1] : [38, 30, 20, 10, 2]
        let stops = levels.enumerated().map { i, v in
            Gradient.Stop(color: Color(white: v / 255), location: Double(i) / Double(levels.count - 1))
        }
        return LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let x = geo.size.width / 2
            let y = model.long
                ? (tag: Y.long.tag, title: Y.long.title, subtitle: Y.long.subtitle, divider: Y.long.divider, countdown: Y.long.countdown)
                : (tag: 0, title: Y.short.title, subtitle: Y.short.subtitle, divider: Y.short.divider, countdown: Y.short.countdown)

            ZStack {
                background

                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Label(ctx.date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)), systemImage: "clock")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .position(x: x, y: h * Y.clock)

                if model.long {
                    Text("Long Break")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.12)))
                        .position(x: x, y: h * y.tag)
                }
                Text(model.long ? "Time for a longer break" : "Rest your eyes")
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .position(x: x, y: h * y.title)
                Text(model.long ? "Step away, stretch, and look into the distance" : "Look at something far away and let your eyes relax")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .position(x: x, y: h * y.subtitle)
                Capsule()
                    .fill(.white.opacity(0.25))
                    .frame(width: 100, height: 2)
                    .position(x: x, y: h * y.divider)
                Text(DurationFormat.clock(model.remaining))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.55))
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy, value: Int(model.remaining.rounded(.up)))
                    .position(x: x, y: h * y.countdown)

                HStack(spacing: 12) {
                    if model.allowSkip {
                        Button(action: model.onSkip) {
                            Label(model.canSkip ? "Skip Break" : "Skip in \(model.skipWait)s",
                                  systemImage: model.canSkip ? "chevron.right.2" : "hourglass")
                                .frame(width: 118)
                        }
                        .disabled(!model.canSkip)
                    }
                    Button(action: model.lockScreen) {
                        Label("Lock Screen", systemImage: "lock")
                            .frame(width: 113)
                    }
                }
                .buttonStyle(PillButtonStyle())
                .position(x: x, y: h * Y.buttons)

                if model.allowSkip {
                    HStack(spacing: 6) {
                        Text("Press")
                        Text("Esc")
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.12)))
                        Text("twice to skip")
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.45))
                    .position(x: x, y: h * Y.hint)
                }
            }
        }
        .ignoresSafeArea()
    }
}

private struct PillButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white.opacity(isEnabled ? 0.95 : 0.4))
            .padding(.horizontal, 16)
            .frame(height: 35)
            .background(Capsule().fill(.white.opacity(configuration.isPressed ? 0.16 : 0.08)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.14)))
    }
}
