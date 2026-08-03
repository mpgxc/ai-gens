import SwiftUI
import AppKit

/// Renders the status item's progress ring into an `NSImage`.
///
/// `MenuBarExtra`'s `label:` is restricted to text / image / image+text: it
/// does not host custom views, does not run animations, and ignores `.font()`
/// and `.imageScale()`. So the ring is drawn with `ImageRenderer` and handed
/// over as an image.
///
/// Cost control, because this runs beside a 1 Hz ticker:
/// progress is quantised to `steps` positions, so a 25-minute session produces
/// at most `steps` renders — roughly one every twelve seconds — and every other
/// tick is a cache hit.
@MainActor
final class StatusIconRenderer {

    private struct Key: Hashable {
        var step: Int
        var phase: Phase
        var state: State
        var coloured: Bool
    }

    enum State: Hashable {
        case idle, running, paused, awaiting
    }

    /// 3° per step: finer than the eye can read at 18pt, coarse enough to
    /// keep renders rare.
    private let steps = 120
    private var cache: [Key: NSImage] = [:]
    private var appearanceObserver: NSKeyValueObservation?

    init() {
        // Template images auto-tint, so appearance changes do not strictly
        // invalidate the cache — flushed anyway as cheap insurance.
        appearanceObserver = NSApp?.observe(\.effectiveAppearance) { [weak self] _, _ in
            Task { @MainActor in self?.cache.removeAll() }
        }
    }

    func image(progress: Double, phase: Phase, state: State, coloured: Bool) -> NSImage {
        let step = max(0, min(steps, Int((progress * Double(steps)).rounded())))
        let key = Key(step: step, phase: phase, state: state, coloured: coloured)
        if let cached = cache[key] { return cached }

        let image = render(step: step, phase: phase, state: state, coloured: coloured)
        // Bounded so a long-running app cannot grow this without limit.
        if cache.count > 128 { cache.removeAll(keepingCapacity: true) }
        cache[key] = image
        return image
    }

    private func render(step: Int, phase: Phase, state: State, coloured: Bool) -> NSImage {
        let side = NSStatusBar.system.thickness - 6   // ~18pt on a standard bar
        let progress = Double(step) / Double(steps)

        let renderer = ImageRenderer(content: StatusRingShape(
            progress: progress,
            phase: phase,
            state: state,
            coloured: coloured,
            side: side
        ))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2

        guard let image = renderer.nsImage else {
            return NSImage(systemSymbolName: "circle", accessibilityDescription: nil) ?? NSImage()
        }
        // Template rendering is what lets the menu bar tint it correctly for
        // light/dark and for the highlighted state while the panel is open.
        image.isTemplate = !coloured
        return image
    }
}

/// The ring as drawn in the menu bar.
///
/// Phase is conveyed by **shape**, not colour: a break's arc is dashed. That
/// keeps the icon readable as a template image and when highlighted, and it
/// satisfies Differentiate Without Color for free.
private struct StatusRingShape: View {
    let progress: Double
    let phase: Phase
    let state: StatusIconRenderer.State
    let coloured: Bool
    let side: CGFloat

    private var lineWidth: CGFloat { phase.isBreak ? 1.9 : 2.4 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(strokeColor.opacity(0.30), lineWidth: lineWidth)

            if state != .idle {
                Circle()
                    .trim(from: 0, to: max(0.0001, progress))
                    .stroke(
                        strokeColor,
                        style: StrokeStyle(
                            lineWidth: lineWidth,
                            lineCap: .round,
                            dash: phase.isBreak ? [2.6, 2.0] : []
                        )
                    )
                    .rotationEffect(.degrees(-90))
            }

            switch state {
            case .paused:
                Image(systemName: "pause.fill")
                    .font(.system(size: side * 0.38, weight: .bold))
                    .foregroundStyle(strokeColor)
            case .awaiting:
                Image(systemName: "chevron.right")
                    .font(.system(size: side * 0.38, weight: .bold))
                    .foregroundStyle(strokeColor)
            case .idle, .running:
                EmptyView()
            }
        }
        .frame(width: side, height: side)
        .padding(1)
        .opacity(state == .paused ? 0.45 : 1)
    }

    private var strokeColor: Color {
        coloured ? Palette.ramp(for: phase).accent : .black   // template inverts to match the bar
    }
}
