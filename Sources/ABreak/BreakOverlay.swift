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

    func hide() {
        let closing = windows
        windows = []
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
    private var lastEscape = Date.distantPast

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard event.keyCode == 53 else { return }
        let now = Date()
        if now.timeIntervalSince(lastEscape) < 1 { onDoubleEscape() }
        lastEscape = now
    }
}

private struct BreakView: View {
    @ObservedObject var model: BreakModel

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.14), .black], startPoint: .top, endPoint: .bottom)

            VStack {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Label(ctx.date.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.top, 40)
                Spacer()
            }

            VStack(spacing: 0) {
                if model.long {
                    Text("Long Break")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 7).fill(.white.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.white.opacity(0.12)))
                        .padding(.bottom, 24)
                }
                Text(model.long ? "Time for a longer break" : "Rest your eyes")
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(model.long ? "Step away, stretch, and look into the distance" : "Look at something far away and let your eyes relax")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.top, 18)
                Capsule()
                    .fill(.white.opacity(0.25))
                    .frame(width: 100, height: 2)
                    .padding(.top, 40)
                Text(DurationFormat.clock(model.remaining))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.55))
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy, value: Int(model.remaining.rounded(.up)))
                    .padding(.top, 40)
            }

            VStack(spacing: 18) {
                Spacer()
                HStack(spacing: 12) {
                    if model.allowSkip {
                        Button(action: model.onSkip) {
                            Label(model.canSkip ? "Skip Break" : "Skip available soon",
                                  systemImage: model.canSkip ? "forward" : "hourglass")
                        }
                        .disabled(!model.canSkip)
                    }
                    Button(action: model.lockScreen) {
                        Label("Lock Screen", systemImage: "lock")
                    }
                }
                .buttonStyle(PillButtonStyle())
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
                }
            }
            .animation(.easeInOut, value: model.canSkip)
            .padding(.bottom, 80)
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
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
            .background(Capsule().fill(.white.opacity(configuration.isPressed ? 0.16 : 0.08)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.14)))
    }
}
