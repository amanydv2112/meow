import AppKit
import SwiftUI

@MainActor
final class RecordingHUD {
    private let model = RecordingHUDModel()
    private var panel: NSPanel?
    private var hostingView: NSHostingView<HUDView>?

    func show() {
        ensurePanel()
        model.level = 0
        positionPanel()

        guard let panel else { return }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    func updateLevel(_ level: Double) {
        let clamped = min(max(level, 0), 1)
        model.level = model.level * 0.55 + clamped * 0.45
    }

    func hide() {
        guard let panel, panel.isVisible else { return }
        model.level = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            panel.animator().alphaValue = 0
        } completionHandler: {
            Task { @MainActor in
                panel.orderOut(nil)
                panel.alphaValue = 1
            }
        }
    }

    private func ensurePanel() {
        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: HUDView.size.width, height: HUDView.size.height),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .floating
            panel.isOpaque = false
            panel.backgroundColor = .clear
            // The content draws its own soft shadow. A window shadow would need
            // invalidating on every waveform frame and would outline the panel
            // rather than the bars.
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            self.panel = panel
        }

        if hostingView == nil {
            let hostingView = NSHostingView(rootView: HUDView(model: model))
            self.hostingView = hostingView
            panel?.contentView = hostingView
        }
    }

    /// Bottom centre, just clear of the Dock. `visibleFrame` already excludes
    /// the Dock and the menu bar, so this also lands correctly when the Dock is
    /// hidden or moved to a side edge.
    private func positionPanel() {
        guard let panel, let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        // The panel carries transparent margin for the shadow, so offset by that
        // margin to keep the pill the intended distance above the Dock.
        let shadowMargin = (HUDView.size.height - HUDView.pillSize.height) / 2
        panel.setFrameOrigin(
            NSPoint(
                x: frame.midX - panel.frame.width / 2,
                y: frame.minY + 14 - shadowMargin
            )
        )
    }
}

@MainActor
private final class RecordingHUDModel: ObservableObject {
    @Published var level: Double = 0
}

/// A dark capsule holding the mic and the waveform, the convention every
/// comparable dictation tool has landed on. The pill is always dark and the
/// marks are always white, rather than following the system appearance, so
/// contrast holds no matter what is on screen behind it.
private struct HUDView: View {
    @ObservedObject var model: RecordingHUDModel

    /// The panel is larger than the pill to leave room for the drop shadow.
    static let size = CGSize(width: 180, height: 54)
    static let pillSize = CGSize(width: 152, height: 34)

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "mic.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.7))

            LevelBars(level: model.level)
                .frame(width: 108, height: 22)
        }
        .frame(width: Self.pillSize.width, height: Self.pillSize.height)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.82))
                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 2)
        )
        .frame(width: Self.size.width, height: Self.size.height)
    }
}

private struct LevelBars: View {
    let level: Double
    private let barCount = 15

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 4.5) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.7 + 0.3 * min(max(level, 0), 1)))
                        .frame(width: 3, height: barHeight(index: index, time: time))
                }
            }
            .animation(.easeOut(duration: 0.08), value: level)
        }
    }

    /// Quiet breathing when silent, a centre-weighted envelope when speaking.
    private func barHeight(index: Int, time: TimeInterval) -> CGFloat {
        let center = Double(barCount - 1) / 2
        let distanceFromCenter = abs(Double(index) - center) / center
        let envelope = 1 - distanceFromCenter * 0.55
        let wobble = (sin(time * 6.2 + Double(index) * 0.7) + 1) / 2
        let idle = 0.05 + wobble * 0.04
        let active = level * envelope * (0.78 + wobble * 0.22)
        let mixed = max(idle, active)
        return 3 + CGFloat(min(max(mixed, 0), 1)) * 19
    }
}
