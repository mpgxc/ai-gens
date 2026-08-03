import SwiftUI
import Charts

/// Focus time charted by day, week or month.
struct StatsPane: View {
    let env: AppEnvironment

    @Environment(\.motion) private var motion
    @State private var granularity: Granularity = .day
    @State private var buckets: [StatsBucket] = []
    @State private var summary = StatsSummary()
    @State private var animateBars = false
    @State private var selected: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Picker("Granularity", selection: $granularity) {
                ForEach(Granularity.allCases) { g in
                    Text(g.title).tag(g)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 280)

            kpis

            chart
                .frame(minHeight: 240)

            Spacer(minLength: 0)
        }
        .padding(26)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: TaskKey(granularity: granularity, count: env.history.sessions.count)) {
            buckets = Stats.buckets(env.history.sessions, by: granularity)
            summary = Stats.summary(env.history.sessions)
            animateBars = false
            // One hop so the bars have a zero state to grow from.
            await Task.yield()
            withAnimation(motion.reveal) { animateBars = true }
        }
    }

    private struct TaskKey: Equatable {
        let granularity: Granularity
        let count: Int
    }

    private var kpis: some View {
        HStack(spacing: 14) {
            kpi("Focused", Stats.durationText(summary.totalFocus))
            kpi("Sessions", "\(summary.sessions)")
            kpi("Streak", "\(summary.streakDays)d")
            kpi("Best day", Stats.durationText(summary.bestDay))
        }
    }

    private func kpi(_ title: LocalizedStringResource, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit())
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .textCase(.uppercase)
                .kerning(0.6)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .cadenceGlass(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var chart: some View {
        Chart {
            ForEach(buckets) { bucket in
                BarMark(
                    x: .value("Period", bucket.start, unit: granularity.calendarComponent),
                    y: .value("Minutes", animateBars ? bucket.focusMinutes : 0)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Palette.ramp(for: .focus).accent, Palette.ramp(for: .focus).secondary],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(6)
                .opacity(selected == nil || selected == bucket.start ? 1 : 0.35)
            }

            if average > 0 {
                RuleMark(y: .value("Average", average))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text("avg \(Int(average))m")
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
            }
        }
        // `.animation` is a View modifier and `ChartContent` has no such member,
        // so this belongs on the chart rather than on each BarMark. Swift Charts
        // interpolates the data change itself; the trade-off against the
        // per-mark version is that the bars grow together instead of staggering.
        .animation(motion.reveal, value: animateBars)
        .chartXSelection(value: $selected)
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.08))
                AxisValueLabel {
                    if let minutes = value.as(Double.self) {
                        Text("\(Int(minutes))m").font(.system(size: 10).monospacedDigit())
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 7)) { _ in
                AxisValueLabel(format: axisFormat)
                    .font(.system(size: 10))
            }
        }
    }

    private var average: Double {
        let active = buckets.filter { $0.focusMinutes > 0 }
        guard !active.isEmpty else { return 0 }
        return active.reduce(0) { $0 + $1.focusMinutes } / Double(active.count)
    }

    private var axisFormat: Date.FormatStyle {
        switch granularity {
        case .day:   .dateTime.weekday(.narrow)
        case .week:  .dateTime.day().month(.narrow)
        case .month: .dateTime.month(.narrow)
        }
    }
}
