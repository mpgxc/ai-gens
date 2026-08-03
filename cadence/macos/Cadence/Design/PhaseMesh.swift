import SwiftUI

/// The animated backdrop, and the reason `.clear` glass is legible anywhere in
/// this app: glass needs rich content beneath it to refract.
///
/// Two independent motions:
/// * **Palette** — the nine colours swap per phase and SwiftUI interpolates
///   them, which is what makes a phase change read as a mood change.
/// * **Drift** — control points wander on slow Lissajous curves.
///
/// Corners stay pinned and edge midpoints only slide *along* their own edge.
/// Letting them leave the boundary tears the mesh visibly.
///
/// Never wrap this in `.drawingGroup()`: rasterising into a layer stops Liquid
/// Glass above it from sampling correctly and silently kills the refraction.
struct PhaseMesh: View {
    let phase: Phase

    @Environment(\.motion) private var motion

    var body: some View {
        Group {
            if motion.reduceTransparency {
                Palette.flatBackdrop(for: phase)
            } else if motion.meshDrifts {
                // 30 Hz rather than the display link: the drift is slow enough
                // that the halved GPU work is invisible.
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
                    mesh(at: context.date.timeIntervalSinceReferenceDate)
                }
            } else {
                mesh(at: 0)
            }
        }
        .animation(motion.meshPalette, value: phase)
    }

    private func mesh(at t: TimeInterval) -> some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: points(at: t),
            colors: Palette.ramp(for: phase).mesh,
            smoothsColors: true
        )
    }

    private func points(at t: TimeInterval) -> [SIMD2<Float>] {
        func wobble(_ speed: Double, _ phaseOffset: Double, _ amplitude: Double) -> Float {
            Float(sin(t * speed + phaseOffset) * amplitude)
        }

        let edge = Float(0.5)
        return [
            // Corners: pinned.
            SIMD2(0, 0),
            SIMD2(edge + wobble(0.21, 0.0, 0.10), 0),          // top edge, slides horizontally
            SIMD2(1, 0),

            SIMD2(0, edge + wobble(0.17, 1.3, 0.10)),          // left edge, slides vertically
            SIMD2(edge + wobble(0.13, 2.1, 0.14),              // centre: free to wander
                  edge + wobble(0.19, 0.7, 0.14)),
            SIMD2(1, edge + wobble(0.15, 3.4, 0.10)),          // right edge

            SIMD2(0, 1),
            SIMD2(edge + wobble(0.23, 4.2, 0.10), 1),          // bottom edge
            SIMD2(1, 1),
        ]
    }
}

/// The opaque content card the panel and window place their controls on.
///
/// Layering rule, applied here so call sites cannot get it wrong:
/// the system already draws a Liquid Glass panel around us, so this card is
/// **opaque**. Glass controls above it then sample the mesh — never the panel
/// material, and never other glass.
struct MeshCard<Content: View>: View {
    let phase: Phase
    var cornerRadius: CGFloat = 22
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background {
                PhaseMesh(phase: phase)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
