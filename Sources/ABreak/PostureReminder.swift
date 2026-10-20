import AppKit
import SwiftUI

/// Click-through "sit up" animation: a pill stretches down, snaps back up into a circle, then shrinks away.
@MainActor
final class PostureReminder {
    private var windows: [NSWindow] = []
    private var hideWork: DispatchWorkItem?

    static let duration: TimeInterval = 3.2
    static let sizes: [CGFloat] = [72, 96, 120]

    func show() {
        hide()
        let width = Self.sizes[min(max(UserDefaults.standard.integer(forKey: Pref.postureSize), 0), Self.sizes.count - 1)]
        let position = min(max(UserDefaults.standard.integer(forKey: Pref.posturePosition), 0), 8)
        let dim = Pref.bool(Pref.dimForReminders)

        for screen in NSScreen.screens {
            let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.setFrame(screen.frame, display: false)
            window.level = .statusBar
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: PostureView(width: width, position: position, dim: dim))
            window.orderFrontRegardless()
            windows.append(window)
        }
        if Pref.bool(Pref.postureSound) { NSSound(named: "Pop")?.play() }

        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.hide() } }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.duration + 0.1, execute: work)
    }

    func hide() {
        hideWork?.cancel()
        windows.forEach { $0.orderOut(nil) }
        windows = []
    }
}

private struct PostureFrame {
    var dim = 0.0
    var outerScale = 0.2
    var outerOpacity = 0.0
    /// Extra pill length below the circle, as a fraction of the width.
    var stretch = 0.0
    /// Vertical lift, as a fraction of the width.
    var lift = 0.0
    var innerScale = 0.0
    var innerOpacity = 0.0
}

private struct PostureView: View {
    let width: CGFloat
    let position: Int
    let dim: Bool
    @State private var trigger = false

    private static let maxStretch = 1.2

    var body: some View {
        KeyframeAnimator(initialValue: PostureFrame(), trigger: trigger) { f in
            GeometryReader { geo in
                ZStack {
                    if dim {
                        RadialGradient(
                            colors: [.black.opacity(0.18), .black.opacity(0.5)],
                            center: .center, startRadius: 0, endRadius: max(geo.size.width, geo.size.height) * 0.6
                        )
                        .opacity(f.dim)
                    }
                    figure(f)
                        .position(anchor(in: geo.size))
                }
            }
            .ignoresSafeArea()
        } keyframes: { _ in
            KeyframeTrack(\.dim) {
                LinearKeyframe(1, duration: 0.3)
                LinearKeyframe(1, duration: 2.5)
                LinearKeyframe(0, duration: 0.4)
            }
            KeyframeTrack(\.outerScale) {
                SpringKeyframe(1, duration: 0.45, spring: .bouncy)
                LinearKeyframe(1, duration: 2.15)
                CubicKeyframe(0.05, duration: 0.4)
            }
            KeyframeTrack(\.outerOpacity) {
                LinearKeyframe(1, duration: 0.2)
                LinearKeyframe(1, duration: 2.6)
                LinearKeyframe(0, duration: 0.2)
            }
            KeyframeTrack(\.stretch) {
                LinearKeyframe(0, duration: 0.45)
                SpringKeyframe(Self.maxStretch, duration: 0.5, spring: .smooth)
                LinearKeyframe(Self.maxStretch, duration: 0.85)
                SpringKeyframe(0, duration: 0.5, spring: .snappy)
            }
            KeyframeTrack(\.lift) {
                LinearKeyframe(0, duration: 1.8)
                SpringKeyframe(0.4, duration: 0.5, spring: .snappy)
            }
            KeyframeTrack(\.innerScale) {
                LinearKeyframe(0, duration: 0.2)
                SpringKeyframe(1, duration: 0.45, spring: .bouncy)
                LinearKeyframe(1, duration: 1.65)
                CubicKeyframe(0.3, duration: 0.4)
            }
            KeyframeTrack(\.innerOpacity) {
                LinearKeyframe(0, duration: 0.2)
                LinearKeyframe(1, duration: 0.25)
                LinearKeyframe(1, duration: 1.85)
                LinearKeyframe(0, duration: 0.4)
            }
        }
        .onAppear { trigger.toggle() }
    }

    private func figure(_ f: PostureFrame) -> some View {
        let inner = width * 0.8
        return ZStack(alignment: .top) {
            Capsule()
                .fill(Color(white: 0.95))
                .overlay(Capsule().strokeBorder(.white.opacity(0.9), lineWidth: 1))
                .shadow(color: .black.opacity(0.19), radius: width * 0.18, y: width * 0.05)
                .frame(width: width, height: width * (1 + f.stretch))
            Circle()
                .fill(LinearGradient(
                    colors: [Color(red: 1.0, green: 0.573, blue: 0.22), Color(red: 0.95, green: 0.38, blue: 0.55), Color(red: 0.902, green: 0.302, blue: 0.808)],
                    startPoint: .topTrailing, endPoint: .bottomLeading
                ))
                .overlay(
                    Image(systemName: "arrow.up")
                        .font(.system(size: inner * 0.42, weight: .heavy))
                        .scaleEffect(x: 1, y: 1.18)
                        .foregroundStyle(Color(white: 0.12))
                )
                .frame(width: inner, height: inner)
                .padding(.top, (width - inner) / 2)
                .scaleEffect(f.innerScale)
                .opacity(f.innerOpacity)
        }
        .scaleEffect(f.outerScale, anchor: .top)
        .opacity(f.outerOpacity)
        // Keep the circle fixed while the pill grows downward; lift moves the whole figure up.
        .frame(width: width, height: width * (1 + Self.maxStretch), alignment: .top)
        .offset(y: -f.lift * width)
    }

    /// 3x3 grid position; the figure's full (stretched) box is centered on the anchor.
    /// The middle row sits above true center: LookAway's stretched pill tops out at ~27% of screen height.
    private func anchor(in size: CGSize) -> CGPoint {
        let margin = width * 1.4
        let col = CGFloat(position % 3), row = position / 3
        let x = margin + (size.width - 2 * margin) * col / 2
        let middleY = size.height * 0.272 + width * (1 + Self.maxStretch) / 2
        let y = [margin, middleY, size.height - margin][row]
        return CGPoint(x: x, y: y)
    }
}
