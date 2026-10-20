import AppKit
import SwiftUI

@MainActor
final class PreBreakModel: ObservableObject {
    @Published var remaining: TimeInterval = 0
    var onStart: () -> Void = {}
    var onPostpone: () -> Void = {}
    var onSkip: () -> Void = {}
}

/// Small non-activating heads-up shown before a break, so typing is not interrupted.
@MainActor
final class PreBreakPanel {
    let model = PreBreakModel()
    private var panel: NSPanel?

    func show(remaining: TimeInterval) {
        model.remaining = remaining
        guard panel == nil, let screen = NSScreen.main else { return }
        let size = NSSize(width: 360, height: 64)
        let frame = NSRect(
            x: screen.visibleFrame.midX - size.width / 2,
            y: screen.visibleFrame.maxY - size.height - 12,
            width: size.width, height: size.height
        )
        let p = NSPanel(contentRect: frame, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.isReleasedWhenClosed = false
        p.contentView = NSHostingView(rootView: PreBreakView(model: model))
        p.orderFrontRegardless()
        panel = p
    }

    func update(remaining: TimeInterval) {
        model.remaining = remaining
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct PreBreakView: View {
    @ObservedObject var model: PreBreakModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "eye")
            Text("Break in \(Int(model.remaining.rounded(.up)))s")
                .monospacedDigit()
            Spacer()
            Button("Now") { model.onStart() }
            Button("In 5 Min") { model.onPostpone() }
            if Pref.bool(Pref.allowSkip) {
                Button("Skip") { model.onSkip() }
            }
        }
        .controlSize(.small)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
