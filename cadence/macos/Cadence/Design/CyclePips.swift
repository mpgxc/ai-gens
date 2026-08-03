import SwiftUI

/// Position within the current cycle — four dots by default, one per focus
/// block before the long break.
struct CyclePips: View {
    let completedFocusCount: Int
    let config: TimerConfig
    let phase: Phase

    @Environment(\.motion) private var motion

    private var total: Int { max(1, min(12, config.longBreakEvery)) }

    /// Routed through `CycleMachine` so the cycle rule lives in exactly one place.
    private var filled: Int {
        CycleMachine.cyclePosition(completedFocusCount: completedFocusCount, config: config) - 1
    }

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(index < filled ? Palette.ramp(for: phase).accent : Color.white.opacity(0.22))
                    .frame(width: 7, height: 7)
                    .scaleEffect(index < filled ? 1 : 0.82)
                    // Stagger the drain when a long break resets the row.
                    .animation(
                        motion.reveal.delay(motion.reduceMotion ? 0 : Double(index) * 0.05),
                        value: filled
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Cycle progress"))
        .accessibilityValue(Text("\(filled) of \(total) focus blocks"))
    }
}
