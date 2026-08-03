import Foundation

/// User-tunable durations and cycle behaviour.
///
/// A plain value type so the engine can be driven deterministically in tests
/// without touching `UserDefaults`.
struct TimerConfig: Sendable, Equatable {
    var focus: Duration
    var shortBreak: Duration
    var longBreak: Duration

    /// How many focus blocks precede a long break.
    var longBreakEvery: Int

    var autoStartBreaks: Bool
    var autoStartFocus: Bool

    static let standard = TimerConfig(
        focus: .seconds(25 * 60),
        shortBreak: .seconds(5 * 60),
        longBreak: .seconds(15 * 60),
        longBreakEvery: 4,
        autoStartBreaks: true,
        autoStartFocus: false
    )

    func duration(for phase: Phase) -> Duration {
        switch phase {
        case .focus:      focus
        case .shortBreak: shortBreak
        case .longBreak:  longBreak
        }
    }

    /// Whether a phase should begin on its own once the previous one ends.
    func autoStarts(_ phase: Phase) -> Bool {
        phase.isBreak ? autoStartBreaks : autoStartFocus
    }

    /// The status item renders `MM:SS` and must never change width, so phases
    /// are capped below an hour. Enforced here rather than at every call site.
    static let maximumPhase = Duration.seconds(59 * 60 + 59)
    static let minimumPhase = Duration.seconds(60)

    static func clamp(_ minutes: Int) -> Duration {
        let d = Duration.seconds(minutes * 60)
        return min(max(d, minimumPhase), maximumPhase)
    }
}
