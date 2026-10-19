import AppKit
import SwiftUI

/// Transient non-activating banner at the top of the main screen (posture reminder).
@MainActor
final class Toast {
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?

    func show(symbol: String, text: String, for seconds: TimeInterval = 6) {
        hide()
        guard let screen = NSScreen.main else { return }
        let size = NSSize(width: 280, height: 52)
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
        p.ignoresMouseEvents = true
        p.contentView = NSHostingView(rootView:
            Label(text, systemImage: symbol)
                .font(.headline)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        )
        p.orderFrontRegardless()
        panel = p

        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.hide() } }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    func hide() {
        hideWork?.cancel()
        panel?.orderOut(nil)
        panel = nil
    }
}
