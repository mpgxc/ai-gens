import SwiftUI

/// The hero ring.
///
/// The single most important rendering decision in the app: there is **no**
/// `withAnimation` and no `.animation` on the trim. The value is recomputed
/// every frame from `context.date`, so it is continuous by construction and
/// physically cannot step once per second.
///
/// `TimelineView(.animation)` registers a display link for as long as it is
/// mounted, so keep it scoped to the ring subtree and never let it wrap the
/// digits or the control cluster. Closing the window or the panel unmounts it,
/// which is what stops the display link.
struct ProgressRing: View {
    let snapshot: TimerSnapshot
    let phase: Phase
    var lineWidth: CGFloat = 10
    var showsComet: Bool = true

    @Environment(\.motion) private var motion

    var body: some View {
        if motion.reduceMotion {
            // Still visually continuous, but one recomposition per second
            // instead of sixty.
            TimelineView(.periodic(from: .now, by: 1)) { context in
                ring(progress: snapshot.progress(at: context.date))
                    .animation(.linear(duration: 1), value: snapshot.progress(at: context.date))
            }
        } else {
            TimelineView(.animation) { context in
                ring(progress: snapshot.progress(at: context.date))
            }
        }
    }

    private func ring(progress: Double) -> some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let inset = lineWidth / 2

            ZStack {
                Circle()
                    .stroke(trackColor, lineWidth: lineWidth)

                Circle()
                    .trim(from: 0, to: max(0.0001, progress))
                    .stroke(
                        Palette.ringGradient(for: phase),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                if showsComet && !motion.reduceMotion && progress > 0.002 {
                    comet(progress: progress, radius: side / 2 - inset)
                }
            }
            .frame(width: side, height: side)
            .padding(inset)
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    /// A blurred dot riding the head of the arc — reads as a travelling glow
    /// without any particle machinery.
    private func comet(progress: Double, radius: CGFloat) -> some View {
        let angle = 2 * .pi * progress - .pi / 2
        return Circle()
            .fill(Palette.ramp(for: phase).glow)
            .frame(width: lineWidth * 1.15, height: lineWidth * 1.15)
            .blur(radius: 3)
            .blendMode(.plusLighter)
            .offset(x: radius * cos(angle), y: radius * sin(angle))
    }

    private var trackColor: Color {
        motion.reduceTransparency ? Color(nsColor: .separatorColor) : .white.opacity(0.12)
    }
}
