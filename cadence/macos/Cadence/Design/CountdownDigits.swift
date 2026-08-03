import SwiftUI

/// The large `MM:SS` readout.
///
/// A deliberate sibling of `ProgressRing`, never a child: nesting it inside the
/// ring's `TimelineView(.animation)` would re-evaluate the per-glyph numeric
/// transition at display-link rate instead of once a second.
///
/// Also deliberately not `Text(timerInterval:pauseTime:countsDown:)` — the
/// system-driven variant updates itself for free but ignores
/// `.contentTransition`, so it cannot do the digit roll.
struct CountdownDigits: View {
    let snapshot: TimerSnapshot
    var size: CGFloat = 56
    var weight: Font.Weight = .medium

    @Environment(\.motion) private var motion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let seconds = Int(snapshot.remaining(at: context.date).rounded(.up))
            Text(TimerSnapshot.clockText(seconds: TimeInterval(seconds)))
                .font(.system(size: size, weight: weight, design: .rounded).monospacedDigit())
                .contentTransition(motion.reduceMotion ? .identity : .numericText(countsDown: true))
                .animation(motion.digits, value: seconds)
                .accessibilityLabel(Text("Time remaining"))
                .accessibilityValue(Text(accessibleValue(seconds: seconds)))
        }
    }

    private func accessibleValue(seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return minutes > 0
            ? String(localized: "\(minutes) minutes \(secs) seconds")
            : String(localized: "\(secs) seconds")
    }
}
