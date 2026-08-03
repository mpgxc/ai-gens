import SwiftUI

/// The `.menuBarExtraStyle(.window)` panel.
///
/// Layering is the thing to get right here, and it follows the "never stack
/// glass on glass" rule literally:
///
/// * **Layer 0** — the panel chrome. macOS already draws a Liquid Glass panel
///   with rounded corners around us, so we add *nothing* at the root: no
///   `.background`, no `.glassEffect`.
/// * **Layer 1** — an **opaque** `MeshCard`, inset so the system glass still
///   reads at the edges. This is the rich content layer.
/// * **Layer 2** — ring and digits, drawn straight onto the mesh. Not glass.
/// * **Layer 3** — the floating control cluster, `.clear` glass, sampling the
///   opaque mesh beneath it rather than the panel material. That is precisely
///   why `.clear` is legible here and why the mesh has to exist.
///
/// On dismissal: there is no public API to close a `.window`-style
/// `MenuBarExtra` panel. So the design never needs one — every primary action
/// acts in place and leaves the panel open showing the result, and the two
/// escapes open a window, which makes the panel resign key and close itself.
struct PanelView: View {

    @Environment(\.openWindow) private var openWindow
    @Environment(\.motion) private var motion
    @Environment(\.openSettings) private var openSettings

    let env: AppEnvironment

    @State private var revealed = false
    @FocusState private var nameFocused: Bool

    private var snapshot: TimerSnapshot { env.engine.snapshot }
    private var phase: Phase { snapshot.phase }

    var body: some View {
        VStack(spacing: 0) {
            MeshCard(phase: phase) {
                VStack(spacing: 14) {
                    header
                    ringStack
                    CyclePips(
                        completedFocusCount: snapshot.completedFocusCount,
                        config: env.engine.config,
                        phase: phase
                    )
                    controls
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 18)
            }
            .padding(10)

            footer
        }
        .frame(width: 320)
        .onAppear { withAnimation(motion.reveal) { revealed = true } }
        .onDisappear { revealed = false }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Text(phase.title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .textCase(.uppercase)
                    .kerning(0.8)
                    .foregroundStyle(.secondary)
                Spacer()
                if let endsAt = snapshot.endsAt {
                    Text(endsAt, format: .dateTime.hour().minute())
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }

            TextField(
                text: Binding(get: { env.engine.sessionName }, set: { env.engine.sessionName = $0 }),
                prompt: Text("What are you focusing on?")
            ) { EmptyView() }
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($nameFocused)
                .disabled(phase.isBreak)
                .opacity(phase.isBreak ? 0.35 : 1)
        }
        .opacity(revealed ? 1 : 0)
    }

    private var ringStack: some View {
        ZStack {
            ProgressRing(snapshot: snapshot, phase: phase, lineWidth: 9)
            CountdownDigits(snapshot: snapshot, size: 38, weight: .semibold)
        }
        .frame(width: 150, height: 150)
        .scaleEffect(revealed ? 1 : 0.92)
        .opacity(revealed ? 1 : 0)
        .animation(motion.reveal.delay(motion.reduceMotion ? 0 : 0.04), value: revealed)
    }

    private var controls: some View {
        ControlCluster(
            phase: phase,
            isRunning: snapshot.isRunning,
            isIdle: snapshot.isIdle,
            startTitle: env.engine.awaitingStart ? "Start \(String(localized: phase.title).lowercased())" : "Start",
            onStart: env.engine.start,
            onPause: env.engine.toggle,
            onSkip: env.skip,
            onStop: env.engine.stop
        )
        .opacity(revealed ? 1 : 0)
        .animation(motion.reveal.delay(motion.reduceMotion ? 0 : 0.10), value: revealed)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            if let missed = env.engine.missedPhase {
                Label {
                    Text("Your \(String(localized: missed.title).lowercased()) ended while the Mac was asleep.")
                        .font(.system(size: 11))
                } icon: {
                    Image(systemName: "moon.zzz.fill")
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
                .transition(.blurReplace)
            }

            VStack(spacing: 5) {
                statRow("Today", value: "\(env.history.focusCountToday()) · \(Stats.durationText(env.history.focusTimeToday()))")
                statRow("This week", value: "\(env.history.focusCountThisWeek()) · \(Stats.durationText(env.history.focusTimeThisWeek()))")
            }
            .padding(.horizontal, 14)

            Divider().padding(.vertical, 10)

            VStack(spacing: 2) {
                panelButton("Open Cadence", symbol: "macwindow") {
                    openWindow(id: MainWindow.identifier)
                    NSApp.activate(ignoringOtherApps: true)
                }
                panelButton("Settings…", symbol: "gearshape") {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                }
                panelButton("Quit Cadence", symbol: "power") {
                    NSApp.terminate(nil)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .opacity(revealed ? 1 : 0)
        .animation(motion.reveal.delay(motion.reduceMotion ? 0 : 0.14), value: revealed)
    }

    private func statRow(_ title: LocalizedStringResource, value: String) -> some View {
        HStack {
            Text(title).font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(size: 11, weight: .medium).monospacedDigit())
        }
    }

    private func panelButton(
        _ title: LocalizedStringResource,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol).frame(width: 16)
                Text(title)
                Spacer()
            }
            .font(.system(size: 12))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }
}
