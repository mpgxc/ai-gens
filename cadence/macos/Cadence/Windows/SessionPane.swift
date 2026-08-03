import SwiftUI

/// The hero timer.
///
/// Phase changes are choreographed rather than snapped: the mesh palette leads
/// the ring by a beat, so the new phase's mood arrives before the geometry
/// settles. That ordering is what sells the transition.
struct SessionPane: View {
    let env: AppEnvironment

    @Environment(\.motion) private var motion
    @State private var handoff = 0
    @FocusState private var nameFocused: Bool

    private var snapshot: TimerSnapshot { env.engine.snapshot }
    private var phase: Phase { snapshot.phase }

    var body: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 0)

            phasePill

            ZStack {
                ProgressRing(snapshot: snapshot, phase: phase, lineWidth: 12)
                VStack(spacing: 6) {
                    CountdownDigits(snapshot: snapshot, size: 62)
                    if let endsAt = snapshot.endsAt {
                        Text("ends \(endsAt, format: .dateTime.hour().minute())")
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(width: 260, height: 260)
            // Recoil: a short overshoot at every phase boundary.
            .phaseAnimator([false, true], trigger: handoff) { view, recoiling in
                view
                    .scaleEffect(recoiling && !motion.reduceMotion ? 0.945 : 1)
                    .saturation(recoiling && !motion.reduceMotion ? 1.3 : 1)
            } animation: { _ in motion.phaseSettle }

            nameField

            CyclePips(
                completedFocusCount: snapshot.completedFocusCount,
                config: env.engine.config,
                phase: phase
            )

            ControlCluster(
                phase: phase,
                isRunning: snapshot.isRunning,
                isIdle: snapshot.isIdle,
                startTitle: "Start \(String(localized: phase.title).lowercased())",
                onStart: env.engine.start,
                onPause: env.engine.toggle,
                onSkip: env.skip,
                onStop: env.engine.stop
            )
            .ambientBreath()

            if let missed = env.engine.missedPhase {
                Label {
                    Text("Your \(String(localized: missed.title).lowercased()) ended while the Mac was asleep. Nothing was started for you.")
                } icon: {
                    Image(systemName: "moon.zzz.fill")
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .transition(.blurReplace)
            }

            Spacer(minLength: 0)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: phase) { handoff += 1 }
    }

    private var phasePill: some View {
        Text(phase.title)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .textCase(.uppercase)
            .kerning(1.1)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .cadenceGlass(Capsule(), tint: Palette.ramp(for: phase).accent.opacity(0.35), overMesh: true)
            .animation(motion.meshPalette, value: phase)
    }

    private var nameField: some View {
        HStack(spacing: 8) {
            TextField(
                text: Binding(get: { env.engine.sessionName }, set: { env.engine.sessionName = $0 }),
                prompt: Text("What are you focusing on?")
            ) { EmptyView() }
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .focused($nameFocused)

            let recents = env.history.recentNames()
            if !recents.isEmpty {
                Menu {
                    ForEach(recents, id: \.self) { name in
                        Button(name) { env.engine.sessionName = name }
                    }
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .frame(maxWidth: 340)
        .cadenceGlass(Capsule(), overMesh: true)
        .opacity(phase.isBreak ? 0.4 : 1)
        .disabled(phase.isBreak)
    }
}
