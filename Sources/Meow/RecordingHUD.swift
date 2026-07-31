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
                contentRect: NSRect(x: 0, y: 0, width: 220, height: 62),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .floating
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
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

    private func positionPanel() {
        guard let panel, let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        panel.setFrameOrigin(
            NSPoint(
                x: frame.midX - panel.frame.width / 2,
                y: frame.maxY - panel.frame.height - 24
            )
        )
    }
}

@MainActor
private final class RecordingHUDModel: ObservableObject {
    @Published var level: Double = 0
}

private struct HUDView: View {
    @ObservedObject var model: RecordingHUDModel

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.14))
                    .frame(width: 34, height: 34)
                Image(systemName: "mic.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.red)
            }

            LevelBars(level: model.level)
                .frame(width: 128, height: 34)
        }
        .padding(.horizontal, 18)
        .frame(width: 220, height: 62)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct LevelBars: View {
    let level: Double
    private let barCount = 11

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 5) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(barColor(for: index))
                        .frame(width: 6, height: barHeight(index: index, time: time))
                }
            }
            .animation(.easeOut(duration: 0.08), value: level)
        }
    }

    private func barHeight(index: Int, time: TimeInterval) -> CGFloat {
        let center = Double(barCount - 1) / 2
        let distanceFromCenter = abs(Double(index) - center) / center
        let voiceShape = 1 - distanceFromCenter * 0.58
        let motion = (sin(time * 7.5 + Double(index) * 0.82) + 1) / 2
        let idleMotion = 0.08 + motion * 0.08
        let activeLevel = max(level, 0.04) * voiceShape + motion * level * 0.22
        let mixed = max(idleMotion, activeLevel)
        return 6 + CGFloat(min(max(mixed, 0), 1)) * 28
    }

    private func barColor(for index: Int) -> Color {
        let midpoint = barCount / 2
        return index <= midpoint ? Color.red.opacity(0.92) : Color.cyan.opacity(0.86)
    }
}
