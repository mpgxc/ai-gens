import Foundation

/// A `TimerSnapshot` reduced to something Codable.
///
/// `ContinuousClock.Instant` has no stable meaning across launches, so only the
/// wall-clock deadline is persisted; the instant is rebuilt relative to "now"
/// on restore.
struct PersistedState: Codable, Sendable {
    var phase: Phase
    var plannedSeconds: TimeInterval
    var deadline: Date?
    var pausedRemaining: TimeInterval?
    var completedFocusCount: Int
    var sessionName: String
    var startedAt: Date?
    var accumulatedPause: TimeInterval

    init(_ snapshot: TimerSnapshot) {
        phase = snapshot.phase
        plannedSeconds = snapshot.planned.seconds
        completedFocusCount = snapshot.completedFocusCount
        sessionName = snapshot.sessionName
        startedAt = snapshot.startedAt
        accumulatedPause = snapshot.accumulatedPause.seconds
        switch snapshot.run {
        case .idle:
            deadline = nil; pausedRemaining = nil
        case .running(let deadline, _):
            self.deadline = deadline; pausedRemaining = nil
        case .paused(let remaining):
            deadline = nil; pausedRemaining = remaining.seconds
        }
    }

    /// Rebuild a snapshot. A deadline already in the past still restores as
    /// `.running` so `TimerEngine.reconcile()` can apply the wake policy
    /// rather than this type silently deciding what happened.
    func snapshot() -> TimerSnapshot {
        let run: TimerSnapshot.Run
        if let deadline {
            let remaining = deadline.timeIntervalSinceNow
            run = .running(
                deadline: deadline,
                instant: ContinuousClock.now.advanced(by: .seconds(remaining))
            )
        } else if let pausedRemaining {
            run = .paused(remaining: .seconds(pausedRemaining))
        } else {
            run = .idle
        }
        return TimerSnapshot(
            phase: phase,
            planned: .seconds(plannedSeconds),
            run: run,
            completedFocusCount: completedFocusCount,
            sessionName: sessionName,
            startedAt: startedAt,
            accumulatedPause: .seconds(accumulatedPause)
        )
    }
}

/// Reads and writes the on-disk history and in-flight state.
///
/// An `actor` so encoding never blocks the main actor. `FocusSession` is
/// `Sendable`, so handing arrays across costs nothing.
actor HistoryFileStore {

    /// Versioned from day one: a v2 migration should be a `switch`, not
    /// archaeology on an unmarked blob.
    struct Envelope: Codable, Sendable {
        var schemaVersion: Int = 1
        var sessions: [FocusSession] = []
    }

    private let directory: URL
    private let sessionsURL: URL
    private let stateURL: URL

    private lazy var encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private lazy var decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init(directoryName: String = "Cadence") {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL.temporaryDirectory
        directory = base.appendingPathComponent(directoryName, isDirectory: true)
        sessionsURL = directory.appendingPathComponent("sessions.json")
        stateURL = directory.appendingPathComponent("state.json")
    }

    var sessionsFileURL: URL { sessionsURL }

    func loadSessions() -> [FocusSession] {
        guard let data = try? Data(contentsOf: sessionsURL) else { return [] }
        return (try? decoder.decode(Envelope.self, from: data))?.sessions ?? []
    }

    func saveSessions(_ sessions: [FocusSession]) throws {
        try ensureDirectory()
        let data = try encoder.encode(Envelope(sessions: sessions))
        // Atomic: a crash mid-write must not be able to truncate the user's history.
        try data.write(to: sessionsURL, options: .atomic)
    }

    func loadState() -> PersistedState? {
        guard let data = try? Data(contentsOf: stateURL) else { return nil }
        return try? decoder.decode(PersistedState.self, from: data)
    }

    func saveState(_ state: PersistedState) {
        guard (try? ensureDirectory()) != nil,
              let data = try? encoder.encode(state)
        else { return }
        try? data.write(to: stateURL, options: .atomic)
    }

    func clearState() {
        try? FileManager.default.removeItem(at: stateURL)
    }

    /// JSON the user can take elsewhere — the "your data is yours" promise.
    func exportData(_ sessions: [FocusSession]) throws -> Data {
        try encoder.encode(Envelope(sessions: sessions))
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
