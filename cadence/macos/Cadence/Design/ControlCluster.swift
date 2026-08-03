import SwiftUI

/// The signature animation: one wide "Start" glass capsule becomes three
/// circular glass controls, and back again.
///
/// How the morph actually works:
/// * All states live in the **same** `GlassEffectContainer`. Glass cannot
///   sample glass, so the container is what merges them into one lensing body
///   and what makes morphing possible at all.
/// * The primary button inherits `glassEffectID("primary")` from the Start
///   capsule, so the glass *stretches* through the shape change instead of
///   crossfading between two unrelated views.
/// * Stop and Skip share a `glassEffectUnion`, so they read as one continuous
///   piece of glass budding off the primary as the container's spacing
///   threshold is crossed. That lensing merge is the whole trick.
///
/// The container is scoped tightly to the cluster on purpose — one
/// `GlassEffectContainer` is one offscreen pass, so wrapping a whole panel in
/// it would be needlessly expensive.
struct ControlCluster: View {

    let phase: Phase
    let isRunning: Bool
    let isIdle: Bool
    var startTitle: LocalizedStringResource

    let onStart: () -> Void
    let onPause: () -> Void
    let onSkip: () -> Void
    let onStop: () -> Void

    @Environment(\.motion) private var motion
    @Namespace private var glassNS

    private var accent: Color { Palette.ramp(for: phase).accent }

    var body: some View {
        GlassEffectContainer(spacing: 22) {
            if isIdle {
                startCapsule
                    .glassEffectID("primary", in: glassNS)
            } else {
                HStack(spacing: 16) {
                    CircleGlassButton(
                        symbol: "stop.fill",
                        diameter: 46,
                        tint: accent,
                        help: "Stop session",
                        action: onStop
                    )
                    .glassEffectID("stop", in: glassNS)
                    .glassEffectUnion(id: "wings", namespace: glassNS)

                    CircleGlassButton(
                        symbol: isRunning ? "pause.fill" : "play.fill",
                        diameter: 62,
                        prominent: true,
                        tint: accent,
                        help: isRunning ? "Pause" : "Resume",
                        action: onPause
                    )
                    .glassEffectID("primary", in: glassNS)

                    CircleGlassButton(
                        symbol: "forward.end.fill",
                        diameter: 46,
                        tint: accent,
                        help: "Skip to next phase",
                        action: onSkip
                    )
                    .glassEffectID("skip", in: glassNS)
                    .glassEffectUnion(id: "wings", namespace: glassNS)
                }
            }
        }
        .glassEffectTransition(motion.reduceMotion ? .identity : .matchedGeometry)
        .animation(motion.morph, value: isIdle)
        .animation(motion.morph, value: isRunning)
    }

    /// The single primary action, and so the only control allowed a tint.
    /// `.glassProminent` supplies its own interaction response — a manual
    /// `.interactive()` would be redundant here and mis-hit-tests anywhere
    /// the shape is not a capsule.
    private var startCapsule: some View {
        Button(action: onStart) {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                Text(startTitle)
            }
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .padding(.horizontal, 26)
            .padding(.vertical, 14)
            .contentShape(Capsule())
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .tint(accent)
        .controlSize(.large)
    }
}

/// The idle "breathing" treatment, applied only where a Start capsule is
/// on-screen and only when ambient motion is permitted.
///
/// `repeatForever` keeps a display link alive indefinitely, which for a menu
/// bar app is measurable idle battery cost and defeats App Nap — so this is
/// explicitly torn down on disappear rather than left running.
struct AmbientBreath: ViewModifier {
    @Environment(\.motion) private var motion
    @State private var breathing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(breathing ? 1.015 : 1.0)
            .animation(
                breathing ? .easeInOut(duration: 2.6).repeatForever(autoreverses: true) : .default,
                value: breathing
            )
            .onAppear { if motion.allowsAmbient { breathing = true } }
            .onDisappear { breathing = false }
    }
}

extension View {
    func ambientBreath() -> some View { modifier(AmbientBreath()) }
}
