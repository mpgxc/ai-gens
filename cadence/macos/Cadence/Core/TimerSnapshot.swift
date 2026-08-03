import Foundation

/// An immutable description of the timer at one moment.
///
/// This is the contract that lets every animated surface be a *pure function
/// of the clock*: views never read a countdown that something else decrements,
/// they call `remaining(at:)`/`progress(at:)` with the date their
/// `TimelineView` handed them. Nothing in this app accumulates ticks, so
/// nothing can drift.
struct TimerSnapshot: Sendable, Equatable {

    enum Run: Sendable, Equatable {
        case idle
        /// `deadline` is for display and persistence; `instant` is authoritative.
        case running(deadline: Date, instant: ContinuousClock.Instant)
        case paused(remaining: Duration)
    }

    var phase: Phase
    var planned: Duration
    var run: Run
    var completedFocusCount: Int
    var sessionName: String
    var startedAt: Date?
    /// Total time spent paused during the current phase — recorded in history,
    /// never used to compute the deadline.
    var accumulatedPause: Duration

    static func idle(phase: Phase = .focus, config: TimerConfig = .standard) -> TimerSnapshot {
        TimerSnapshot(
            phase: phase,
            planned: config.duration(for: phase),
            run: .idle,
            completedFocusCount: 0,
            sessionName: "",
            startedAt: nil,
            accumulatedPause: .zero
        )
    }

    var isRunning: Bool { if case .running = run { true } else { false } }
    var isPaused:  Bool { if case .paused  = run { true } else { false } }
    var isIdle:    Bool { if case .idle    = run { true } else { false } }

    /// Wall-clock moment the current phase ends, if it is running.
    var endsAt: Date? {
        if case .running(let deadline, _) = run { deadline } else { nil }
    }

    // MARK: - Derived values

    /// Seconds left, never negative.
    ///
    /// Uses the `Date` deadline because that is what `TimelineView` supplies.
    /// A few milliseconds of skew against the `ContinuousClock` instant after
    /// an NTP correction is invisible, and the authoritative instant is what
    /// actually fires completion.
    func remaining(at now: Date) -> TimeInterval {
        switch run {
        case .idle:
            return planned.seconds
        case .running(let deadline, _):
            return max(0, deadline.timeIntervalSince(now))
        case .paused(let remaining):
            return remaining.seconds
        }
    }

    /// 0...1 through the current phase.
    func progress(at now: Date) -> Double {
        let total = planned.seconds
        guard total > 0 else { return 0 }
        return min(1, max(0, 1 - remaining(at: now) / total))
    }

    /// Zero-padded `MM:SS`. Always five characters so the status item never
    /// changes width and shoves its neighbours around.
    func clockText(at now: Date) -> String {
        Self.clockText(seconds: remaining(at: now))
    }

    static func clockText(seconds: TimeInterval) -> String {
        // `DateComponentsFormatter` allocates and is comparatively slow; this
        // runs once a second forever, so it stays cheap and boring.
        let total = Int(seconds.rounded(.up))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

extension Duration {
    /// `Duration` as fractional seconds.
    var seconds: TimeInterval {
        let (secs, atto) = components
        return TimeInterval(secs) + TimeInterval(atto) / 1e18
    }
}
