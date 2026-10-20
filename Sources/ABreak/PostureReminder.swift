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
    /// Top of the pill (head, where the circle sits) and its bottom (tail), in widths below
    /// the circle's final top edge. Head leads upward, tail follows: a swipe-up gesture.
    var head = PostureView.startHead
    var tail = PostureView.startTail
    var outerScale = 0.2
    var outerOpacity = 0.0
    var innerScale = 0.0
    var innerOpacity = 0.0
}

private struct PostureView: View {
    let width: CGFloat
    let position: Int
    let dim: Bool
    @State private var trigger = false

    /// Geometry in widths, from LookAway frames: the stretched pill is ~2.2 widths tall and its
    /// head sits ~0.4 widths below where the circle finally rests.
    static let stretchedHead = 0.4
    static let span = stretchedHead + 2.22
    /// The figure appears as a circle at the bottom of the future pill.
    static let startHead = span - 1
    static let startTail = span

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
            // 0-0.3 s appear as a circle; 0.3-0.85 s head shoots up, tail stays (pill stretches up);
            // 1.25-1.8 s tail catches up while the head settles a little higher (pill collapses upward).
            KeyframeTrack(\.head) {
                LinearKeyframe(Self.startHead, duration: 0.3)
                SpringKeyframe(Self.stretchedHead, duration: 0.55, spring: .snappy)
                LinearKeyframe(Self.stretchedHead, duration: 0.4)
                SpringKeyframe(0, duration: 0.55, spring: .smooth)
            }
            KeyframeTrack(\.tail) {
                LinearKeyframe(Self.startTail, duration: 1.25)
                SpringKeyframe(1, duration: 0.55, spring: .snappy)
            }
            KeyframeTrack(\.outerScale) {
                SpringKeyframe(1, duration: 0.3, spring: .bouncy)
                LinearKeyframe(1, duration: 2.3)
                CubicKeyframe(0.05, duration: 0.4)
            }
            KeyframeTrack(\.outerOpacity) {
                LinearKeyframe(1, duration: 0.2)
                LinearKeyframe(1, duration: 2.6)
                LinearKeyframe(0, duration: 0.2)
            }
            KeyframeTrack(\.innerScale) {
                LinearKeyframe(0, duration: 0.1)
                SpringKeyframe(1, duration: 0.35, spring: .bouncy)
                LinearKeyframe(1, duration: 1.85)
                CubicKeyframe(0.3, duration: 0.4)
            }
            KeyframeTrack(\.innerOpacity) {
                LinearKeyframe(0, duration: 0.1)
                LinearKeyframe(1, duration: 0.2)
                LinearKeyframe(1, duration: 2.0)
                LinearKeyframe(0, duration: 0.4)
            }
        }
        .onAppear { trigger.toggle() }
    }

    private func figure(_ f: PostureFrame) -> some View {
        let inner = width * 0.8
        let top = CGFloat(f.head) * width
        let length = CGFloat(max(f.tail - f.head, 1)) * width
        let box = CGFloat(Self.span) * width
        // Scale around the circle so appearing/vanishing happens where the circle is.
        let anchor = UnitPoint(x: 0.5, y: (top + width / 2) / box)
        return ZStack(alignment: .top) {
            Capsule()
                .fill(Color(white: 0.95))
                .overlay(Capsule().strokeBorder(.white.opacity(0.9), lineWidth: 1))
                .shadow(color: .black.opacity(0.19), radius: width * 0.18, y: width * 0.05)
                .frame(width: width, height: length)
                .offset(y: top)
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
                .scaleEffect(f.innerScale)
                .opacity(f.innerOpacity)
                .offset(y: top + (width - inner) / 2)
        }
        .frame(width: width, height: box, alignment: .top)
        .scaleEffect(f.outerScale, anchor: anchor)
        .opacity(f.outerOpacity)
    }

    /// 3x3 grid position of the figure's box (final circle top to the stretched pill's bottom).
    /// Middle row: the stretched pill's top sits at ~27% of screen height, as measured on LookAway.
    private func anchor(in size: CGSize) -> CGPoint {
        let margin = width * 0.6
        let box = CGFloat(Self.span) * width
        let col = CGFloat(position % 3), row = position / 3
        let x = width + (size.width - 2 * width) * col / 2
        let middleTop = size.height * 0.272 - CGFloat(Self.stretchedHead) * width
        let top = [margin, middleTop, size.height - margin - box][row]
        return CGPoint(x: x, y: top + box / 2)
    }
}
