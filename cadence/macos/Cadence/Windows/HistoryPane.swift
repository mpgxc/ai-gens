import SwiftUI

/// Finished sessions, newest first, grouped by day.
struct HistoryPane: View {
    let env: AppEnvironment

    @Environment(\.motion) private var motion

    private struct Day: Identifiable {
        var id: Date { date }
        let date: Date
        let sessions: [FocusSession]
        var focusTime: TimeInterval {
            sessions.filter { $0.phase == .focus && $0.completed }.reduce(0) { $0 + $1.activeDuration }
        }
    }

    private var days: [Day] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: env.history.sessions) {
            calendar.startOfDay(for: $0.startedAt)
        }
        return grouped
            .map { Day(date: $0.key, sessions: $0.value.sorted { $0.startedAt > $1.startedAt }) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        Group {
            if env.history.sessions.isEmpty {
                ContentUnavailableView(
                    "No sessions yet",
                    systemImage: "clock.badge.questionmark",
                    description: Text("Finished focus blocks and breaks show up here.")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22, pinnedViews: .sectionHeaders) {
                        ForEach(days) { day in
                            Section {
                                ForEach(day.sessions) { session in
                                    // `reduceMotion` is read once, outside the
                                    // closure: `scrollTransition`'s builder is
                                    // nonisolated, so touching the main-actor
                                    // `motion` from inside it is a data race
                                    // that Swift 6 flags.
                                    let reduceMotion = motion.reduceMotion
                                    row(session)
                                        .scrollTransition { content, phase in
                                            content
                                                .opacity(phase.isIdentity ? 1 : 0)
                                                .scaleEffect(phase.isIdentity || reduceMotion ? 1 : 0.96)
                                        }
                                }
                            } header: {
                                header(day)
                            }
                        }
                    }
                    .padding(24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func header(_ day: Day) -> some View {
        HStack {
            Text(day.date, format: .dateTime.weekday(.wide).day().month(.abbreviated))
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Text(Stats.durationText(day.focusTime))
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func row(_ session: FocusSession) -> some View {
        HStack(spacing: 12) {
            Image(systemName: session.phase.symbolName)
                .font(.system(size: 13))
                .frame(width: 26, height: 26)
                .background(
                    Palette.ramp(for: session.phase).accent.opacity(0.18),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .foregroundStyle(Palette.ramp(for: session.phase).accent)

            VStack(alignment: .leading, spacing: 1) {
                Text(session.name.isEmpty ? String(localized: session.phase.title) : session.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(session.startedAt, format: .dateTime.hour().minute())
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if !session.completed {
                Text("stopped early")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }

            Text(Stats.durationText(session.activeDuration))
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(session.completed ? .primary : .secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Delete", role: .destructive) {
                withAnimation(motion.reveal) { env.history.delete(session) }
            }
        }
    }
}
