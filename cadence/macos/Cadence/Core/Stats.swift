import Foundation

enum Granularity: String, CaseIterable, Identifiable, Sendable {
    case day, week, month
    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .day:   "Day"
        case .week:  "Week"
        case .month: "Month"
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .day:   .day
        case .week:  .weekOfYear
        case .month: .month
        }
    }

    /// How far back the chart looks by default.
    var lookback: DateComponents {
        switch self {
        case .day:   DateComponents(day: -13)      // two weeks of bars
        case .week:  DateComponents(weekOfYear: -11)
        case .month: DateComponents(month: -11)
        }
    }
}

struct StatsBucket: Identifiable, Sendable, Equatable {
    var start: Date
    var focusTime: TimeInterval
    var sessions: Int
    var completed: Int

    var id: Date { start }
    var completionRate: Double { sessions == 0 ? 0 : Double(completed) / Double(sessions) }
    var focusMinutes: Double { focusTime / 60 }
}

struct StatsSummary: Sendable, Equatable {
    var totalFocus: TimeInterval = 0
    var sessions: Int = 0
    var streakDays: Int = 0
    var bestDay: TimeInterval = 0
}

/// Pure aggregation over the session log.
///
/// Cheap enough to run on demand — a year of data is a few thousand records —
/// so there is no cache to invalidate.
enum Stats {

    /// Buckets `sessions` by `granularity`, **emitting empty buckets** for
    /// periods with no activity. Skipping them would make a bar chart quietly
    /// misrepresent a week off as a week that never happened.
    static func buckets(
        _ sessions: [FocusSession],
        by granularity: Granularity,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> [StatsBucket] {
        guard let end = calendar.dateInterval(of: granularity.calendarComponent, for: now)?.start,
              let start = calendar.date(byAdding: granularity.lookback, to: end)
        else { return [] }

        // Only completed focus blocks count as focus time.
        let focus = sessions.filter { $0.phase == .focus }
        var byPeriod: [Date: StatsBucket] = [:]

        for session in focus {
            guard let key = calendar.dateInterval(of: granularity.calendarComponent, for: session.startedAt)?.start,
                  key >= start, key <= end
            else { continue }
            var bucket = byPeriod[key] ?? StatsBucket(start: key, focusTime: 0, sessions: 0, completed: 0)
            bucket.sessions += 1
            if session.completed {
                bucket.completed += 1
                bucket.focusTime += session.activeDuration
            }
            byPeriod[key] = bucket
        }

        var result: [StatsBucket] = []
        var cursor = start
        while cursor <= end {
            result.append(byPeriod[cursor] ?? StatsBucket(start: cursor, focusTime: 0, sessions: 0, completed: 0))
            guard let next = calendar.date(byAdding: granularity.calendarComponent, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    static func summary(
        _ sessions: [FocusSession],
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> StatsSummary {
        let focus = sessions.filter { $0.phase == .focus && $0.completed }
        guard !focus.isEmpty else { return StatsSummary() }

        var perDay: [Date: TimeInterval] = [:]
        for session in focus {
            let day = calendar.startOfDay(for: session.startedAt)
            perDay[day, default: 0] += session.activeDuration
        }

        // Streak counts back from today, tolerating "today hasn't happened yet"
        // by starting at yesterday when today is empty.
        var streak = 0
        var day = calendar.startOfDay(for: now)
        if perDay[day] == nil, let yesterday = calendar.date(byAdding: .day, value: -1, to: day) {
            day = yesterday
        }
        while perDay[day] != nil {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }

        return StatsSummary(
            totalFocus: focus.reduce(0) { $0 + $1.activeDuration },
            sessions: focus.count,
            streakDays: streak,
            bestDay: perDay.values.max() ?? 0
        )
    }

    /// `2h 05m`, or `35m` under an hour.
    static func durationText(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        return minutes >= 60
            ? String(format: "%dh %02dm", minutes / 60, minutes % 60)
            : "\(minutes)m"
    }
}
