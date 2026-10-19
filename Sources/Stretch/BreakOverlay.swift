import AppKit
import SwiftUI

@MainActor
final class BreakModel: ObservableObject {
    @Published var remaining: TimeInterval = 0
    @Published var total: TimeInterval = 1
    @Published var long = false
    @Published var allowSkip = true
    var onSkip: () -> Void = {}
    var onPostpone: () -> Void = {}
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
        guard windows.isEmpty else { return }

        for screen in NSScreen.screens {
            let window = OverlayWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.setFrame(screen.frame, display: false)
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.isOpaque = false
            window.backgroundColor = .clear
            window.isReleasedWhenClosed = false
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

private struct BlurBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .fullScreenUI
        v.blendingMode = .behindWindow
        v.state = .active
        v.appearance = NSAppearance(named: .darkAqua)
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

private struct BreakView: View {
    @ObservedObject var model: BreakModel

    var body: some View {
        ZStack {
            BlurBackground()
            Color.black.opacity(0.35)
            VStack(spacing: 28) {
                Text(model.long ? "起身活动一下" : "让眼睛休息一下")
                    .font(.system(size: 46, weight: .regular, design: .serif))
                    .italic()
                Text(model.long ? "离开屏幕，伸展肩颈，喝点水" : "看向 6 米外的物体，放松眼部肌肉")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.75))
                Text(clock(model.remaining))
                    .font(.system(size: 96, weight: .ultraLight, design: .rounded))
                    .monospacedDigit()
                ProgressView(value: 1 - model.remaining / max(model.total, 1))
                    .progressViewStyle(.linear)
                    .tint(.white)
                    .frame(width: 320)
                HStack(spacing: 16) {
                    Button("推迟 5 分钟") { model.onPostpone() }
                    if model.allowSkip {
                        Button("跳过") { model.onSkip() }
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                if model.allowSkip {
                    Text("连按两次 Esc 跳过")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .foregroundStyle(.white)
        }
        .ignoresSafeArea()
    }
}

func clock(_ seconds: TimeInterval) -> String {
    let s = Int(seconds.rounded(.up))
    return String(format: "%d:%02d", s / 60, s % 60)
}
