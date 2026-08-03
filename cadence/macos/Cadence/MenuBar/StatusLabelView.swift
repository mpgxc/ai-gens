import SwiftUI

/// What actually appears in the menu bar.
///
/// Width stability is a hard requirement: the text is always zero-padded
/// `MM:SS` and always `.monospacedDigit()`, so the item never resizes and
/// never shoves its neighbours around. Phases are capped below an hour
/// (`TimerConfig.maximumPhase`) so five characters is always enough.
struct StatusLabelView: View {

    let engine: TimerEngine
    let ticker: MenuBarTicker
    let renderer: StatusIconRenderer
    let style: MenuBarStyle
    let coloured: Bool

    var body: some View {
        // Reading `ticker.tick` is what re-evaluates this view once a second.
        let _ = ticker.tick
        let now = Date()
        let snapshot = engine.snapshot

        HStack(spacing: 4) {
            if style.showsRing {
                Image(nsImage: renderer.image(
                    progress: snapshot.progress(at: now),
                    phase: snapshot.phase,
                    state: state,
                    coloured: coloured
                ))
            }
            if style.showsTime, let text = timeText(snapshot: snapshot, now: now) {
                Text(text).monospacedDigit()
            }
        }
        .accessibilityLabel(Text(accessibilityLabel(snapshot: snapshot, now: now)))
    }

    private var state: StatusIconRenderer.State {
        if engine.awaitingStart { return .awaiting }
        if engine.snapshot.isRunning { return .running }
        if engine.snapshot.isPaused { return .paused }
        return .idle
    }

    private func timeText(snapshot: TimerSnapshot, now: Date) -> String? {
        switch state {
        case .idle:
            // Nothing to count down yet; the ring alone says "ready".
            return style == .timeOnly ? snapshot.clockText(at: now) : nil
        case .running, .paused, .awaiting:
            return snapshot.clockText(at: now)
        }
    }

    private func accessibilityLabel(snapshot: TimerSnapshot, now: Date) -> String {
        let phase = String(localized: snapshot.phase.title)
        let minutes = Int(snapshot.remaining(at: now) / 60)
        switch state {
        case .idle:     return String(localized: "Cadence, ready")
        case .running:  return String(localized: "\(phase), \(minutes) minutes remaining")
        case .paused:   return String(localized: "\(phase), paused, \(minutes) minutes remaining")
        case .awaiting: return String(localized: "\(phase) ready to start")
        }
    }
}
