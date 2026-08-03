import SwiftUI

/// Liquid Glass with a Reduce Transparency fallback that keeps the same shape
/// and the same metrics, so nothing shifts when the setting flips.
///
/// House rules encoded here:
/// * `.clear` glass is only legible over rich content, so it is reserved for
///   surfaces sitting directly on `PhaseMesh` and is upgraded to `.regular`
///   everywhere else.
/// * Never stack glass on glass — callers group siblings in a
///   `GlassEffectContainer`, because glass cannot sample glass.
/// * `.interactive()` mis-hit-tests non-capsule shapes, so buttons use
///   `.buttonStyle(.glass)` instead of asking for it here.
/// `InsettableShape`, not `Shape`: the opaque fallback draws its border with
/// `strokeBorder`, which insets by half the line width so the stroke stays
/// inside the shape's bounds. Plain `Shape` has no such member. Every call site
/// already passes `Capsule`, `Circle` or `RoundedRectangle`, all of which
/// conform, and `glassEffect(in:)` still accepts it since `InsettableShape`
/// refines `Shape`.
struct GlassSurface<S: InsettableShape>: ViewModifier {
    let shape: S
    var tint: Color?
    var overMesh: Bool

    @Environment(\.motion) private var motion

    func body(content: Content) -> some View {
        if motion.reduceTransparency {
            content
                .background(Color(nsColor: .controlBackgroundColor), in: shape)
                .overlay(shape.strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1))
        } else {
            content.glassEffect(glass, in: shape)
        }
    }

    private var glass: Glass {
        let base: Glass = overMesh ? .clear : .regular
        return tint.map { base.tint($0) } ?? base
    }
}

extension View {
    /// - Parameter overMesh: pass `true` only when this surface sits directly
    ///   on `PhaseMesh`; that is the one place `.clear` glass reads correctly.
    func cadenceGlass<S: InsettableShape>(
        _ shape: S,
        tint: Color? = nil,
        overMesh: Bool = false
    ) -> some View {
        modifier(GlassSurface(shape: shape, tint: tint, overMesh: overMesh))
    }

    func cadenceGlass(tint: Color? = nil, overMesh: Bool = false) -> some View {
        modifier(GlassSurface(shape: Capsule(), tint: tint, overMesh: overMesh))
    }
}

/// A circular glass control.
///
/// Uses `.buttonStyle(.glass)` + `.buttonBorderShape(.circle)` rather than
/// `Glass.regular.interactive()`, which reports capsule-shaped hit testing on
/// circles. Hover state is owned per-button on purpose: hoisting it to the
/// cluster would re-render all three children and force a fresh offscreen
/// glass pass on every hover frame.
struct CircleGlassButton: View {
    let symbol: String
    var diameter: CGFloat = 46
    var prominent: Bool = false
    var tint: Color = .accentColor
    var help: LocalizedStringResource
    let action: () -> Void

    @Environment(\.motion) private var motion
    @State private var isHovered = false
    @State private var pressCount = 0

    var body: some View {
        // The two glass button styles have different opaque types, so the
        // branch happens here rather than inside a wrapper style.
        Group {
            if prominent {
                button.buttonStyle(.glassProminent)
            } else {
                button.buttonStyle(.glass)
            }
        }
        .buttonBorderShape(.circle)
        .clipShape(Circle())      // .glassProminent leaves artefacts on circles without this
        .tint(tint)
        .scaleEffect(isHovered && !motion.reduceMotion ? 1.06 : 1)
        .brightness(isHovered ? 0.06 : 0)
        .animation(motion.hover, value: isHovered)
        .onHover { isHovered = $0 }
        .help(Text(help))
        .accessibilityLabel(Text(help))
    }

    private var button: some View {
        Button {
            pressCount += 1
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: diameter * 0.34, weight: .semibold))
                .symbolEffect(.bounce.down, value: pressCount)
                .frame(width: diameter, height: diameter)
                .contentShape(Circle())
        }
    }
}
