import Foundation

/// One finished (or abandoned) interval, as written to history.
///
/// Times are stored as `TimeInterval`/`Date` rather than `Duration` so the
/// on-disk JSON stays human-readable — this file is the user's data and the
/// app promises they can take it elsewhere.
struct FocusSession: Identifiable, Codable, Sendable, Hashable {
    var id: UUID
    var phase: Phase
    /// What the user was working on. Empty for breaks and unnamed sessions.
    var name: String
    var startedAt: Date
    var endedAt: Date
    /// The phase length the user had configured when it started.
    var planned: TimeInterval
    var pausedTotal: TimeInterval
    /// `false` when the session was stopped early or abandoned to sleep.
    var completed: Bool

    init(
        id: UUID = UUID(),
        phase: Phase,
        name: String,
        startedAt: Date,
        endedAt: Date,
        planned: TimeInterval,
        pausedTotal: TimeInterval,
        completed: Bool
    ) {
        self.id = id
        self.phase = phase
        self.name = name
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.planned = planned
        self.pausedTotal = pausedTotal
        self.completed = completed
    }

    /// Time actually spent in the phase, excluding pauses.
    var activeDuration: TimeInterval {
        max(0, endedAt.timeIntervalSince(startedAt) - pausedTotal)
    }
}
