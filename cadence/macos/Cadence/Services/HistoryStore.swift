import Foundation
import Observation

/// The in-memory session log the UI reads, backed by `HistoryFileStore`.
///
/// A year of use is roughly four thousand records of about 120 bytes, so the
/// whole log lives in memory permanently and the charts aggregate from there.
@MainActor
@Observable
final class HistoryStore {

    private(set) var sessions: [FocusSession] = []
    private(set) var isLoaded = false

    private let file: HistoryFileStore
    private var saveTask: Task<Void, Never>?

    init(file: HistoryFileStore) {
        self.file = file
    }

    func load() async {
        sessions = await file.loadSessions()
        isLoaded = true
    }

    func append(_ session: FocusSession) {
        // Breaks are recorded too — they are what make "did I actually rest?"
        // answerable — but zero-length noise is not worth keeping.
        guard session.activeDuration >= 1 else { return }
        sessions.append(session)
        scheduleSave()
    }

    func delete(_ session: FocusSession) {
        sessions.removeAll { $0.id == session.id }
        scheduleSave()
    }

    func deleteAll() {
        sessions.removeAll()
        scheduleSave()
    }

    /// Debounced so a burst of changes costs one write. Always paired with
    /// `flush()` on terminate and sleep.
    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = sessions
        saveTask = Task { [file] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            try? await file.saveSessions(snapshot)
        }
    }

    func flush() async {
        saveTask?.cancel()
        try? await file.saveSessions(sessions)
    }

    func exportJSON() async -> Data? {
        try? await file.exportData(sessions)
    }

    // MARK: - Queries used by the panel and the history pane

    func sessionsToday(calendar: Calendar = .current, now: Date = Date()) -> [FocusSession] {
        let day = calendar.startOfDay(for: now)
        return sessions.filter { $0.startedAt >= day }
    }

    func focusTimeToday(calendar: Calendar = .current, now: Date = Date()) -> TimeInterval {
        sessionsToday(calendar: calendar, now: now)
            .filter { $0.phase == .focus && $0.completed }
            .reduce(0) { $0 + $1.activeDuration }
    }

    func focusCountToday(calendar: Calendar = .current, now: Date = Date()) -> Int {
        sessionsToday(calendar: calendar, now: now)
            .count { $0.phase == .focus && $0.completed }
    }

    func focusTimeThisWeek(calendar: Calendar = .current, now: Date = Date()) -> TimeInterval {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return sessions
            .filter { $0.phase == .focus && $0.completed && week.contains($0.startedAt) }
            .reduce(0) { $0 + $1.activeDuration }
    }

    func focusCountThisWeek(calendar: Calendar = .current, now: Date = Date()) -> Int {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return sessions.count { $0.phase == .focus && $0.completed && week.contains($0.startedAt) }
    }

    /// Distinct recent session names, newest first — powers the name field's
    /// suggestion menu.
    func recentNames(limit: Int = 6) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for session in sessions.reversed() where session.phase == .focus {
            let name = session.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, seen.insert(name).inserted else { continue }
            result.append(name)
            if result.count == limit { break }
        }
        return result
    }
}
