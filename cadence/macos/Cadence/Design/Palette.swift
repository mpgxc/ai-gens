import SwiftUI

/// Per-phase colour ramps.
///
/// Focus runs warm (amber → coral), breaks run cool (mint → sky), the long
/// break runs violet. Swapping these arrays inside `withAnimation` is what
/// makes the whole app crossfade at a phase boundary, because `MeshGradient`
/// interpolates its colours natively.
enum Palette {

    struct Ramp {
        var accent: Color
        var secondary: Color
        var glow: Color
        /// Nine stops for the 3×3 mesh, row-major.
        var mesh: [Color]
    }

    static func ramp(for phase: Phase) -> Ramp {
        switch phase {
        case .focus:
            Ramp(
                accent: Color(red: 1.00, green: 0.60, blue: 0.30),
                secondary: Color(red: 1.00, green: 0.37, blue: 0.43),
                glow: Color(red: 1.00, green: 0.52, blue: 0.32),
                mesh: [
                    Color(red: 0.34, green: 0.12, blue: 0.16), Color(red: 0.58, green: 0.22, blue: 0.16), Color(red: 0.32, green: 0.10, blue: 0.20),
                    Color(red: 0.62, green: 0.28, blue: 0.16), Color(red: 0.96, green: 0.55, blue: 0.28), Color(red: 0.70, green: 0.20, blue: 0.28),
                    Color(red: 0.22, green: 0.08, blue: 0.14), Color(red: 0.44, green: 0.16, blue: 0.18), Color(red: 0.18, green: 0.06, blue: 0.14),
                ]
            )
        case .shortBreak:
            Ramp(
                accent: Color(red: 0.30, green: 0.88, blue: 0.76),
                secondary: Color(red: 0.22, green: 0.74, blue: 0.97),
                glow: Color(red: 0.28, green: 0.82, blue: 0.86),
                mesh: [
                    Color(red: 0.05, green: 0.20, blue: 0.24), Color(red: 0.08, green: 0.34, blue: 0.38), Color(red: 0.05, green: 0.18, blue: 0.30),
                    Color(red: 0.10, green: 0.40, blue: 0.42), Color(red: 0.26, green: 0.78, blue: 0.72), Color(red: 0.12, green: 0.44, blue: 0.62),
                    Color(red: 0.04, green: 0.14, blue: 0.20), Color(red: 0.06, green: 0.26, blue: 0.34), Color(red: 0.03, green: 0.12, blue: 0.24),
                ]
            )
        case .longBreak:
            Ramp(
                accent: Color(red: 0.66, green: 0.55, blue: 0.98),
                secondary: Color(red: 0.43, green: 0.55, blue: 0.98),
                glow: Color(red: 0.56, green: 0.52, blue: 0.98),
                mesh: [
                    Color(red: 0.14, green: 0.11, blue: 0.30), Color(red: 0.24, green: 0.18, blue: 0.48), Color(red: 0.12, green: 0.12, blue: 0.34),
                    Color(red: 0.28, green: 0.22, blue: 0.54), Color(red: 0.60, green: 0.50, blue: 0.94), Color(red: 0.30, green: 0.32, blue: 0.72),
                    Color(red: 0.09, green: 0.07, blue: 0.22), Color(red: 0.17, green: 0.14, blue: 0.36), Color(red: 0.07, green: 0.07, blue: 0.20),
                ]
            )
        }
    }

    /// Flat backdrop used when Reduce Transparency is on, where a mesh would
    /// fight the requirement for legible, high-contrast surfaces.
    static func flatBackdrop(for phase: Phase) -> LinearGradient {
        let r = ramp(for: phase)
        return LinearGradient(
            colors: [r.mesh[0], r.mesh[8]],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Gradient for the progress ring. First and last stops repeat so the
    /// angular sweep has no visible seam where it wraps.
    static func ringGradient(for phase: Phase) -> AngularGradient {
        let r = ramp(for: phase)
        return AngularGradient(
            stops: [
                .init(color: r.accent, location: 0),
                .init(color: r.secondary, location: 0.45),
                .init(color: r.glow, location: 0.78),
                .init(color: r.accent, location: 1),
            ],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }
}
