import SwiftUI

/// Every animation curve in the app, named once.
///
/// Views ask for `motion.morph`, never for a literal spring. That makes the
/// accessibility degradation a one-file change instead of a thirty-file audit.
struct MotionTokens {

    var morph: Animation
    var phaseSettle: Animation
    var meshPalette: Animation
    var digits: Animation
    var hover: Animation
    var reveal: Animation

    /// Whether decorative, indefinitely-repeating motion is allowed at all.
    /// A `repeatForever` animation keeps a display link alive, which for a
    /// menu bar app is real idle battery cost — so it is gated, not merely
    /// shortened.
    var allowsAmbient: Bool
    var meshDrifts: Bool
    var reduceMotion: Bool
    var reduceTransparency: Bool

    static let standard = MotionTokens(
        morph: .spring(response: 0.45, dampingFraction: 0.78),
        phaseSettle: .spring(response: 0.50, dampingFraction: 0.62),
        meshPalette: .easeInOut(duration: 0.9),
        digits: .snappy(duration: 0.28),
        hover: .smooth(duration: 0.22),
        reveal: .spring(response: 0.40, dampingFraction: 0.85),
        allowsAmbient: true,
        meshDrifts: true,
        reduceMotion: false,
        reduceTransparency: false
    )

    static func resolve(reduceMotion: Bool, reduceTransparency: Bool) -> MotionTokens {
        guard reduceMotion else {
            var tokens = standard
            tokens.reduceTransparency = reduceTransparency
            return tokens
        }
        return MotionTokens(
            morph: .easeOut(duration: 0.15),
            phaseSettle: .easeOut(duration: 0.20),
            meshPalette: .easeInOut(duration: 0.30),
            digits: .linear(duration: 0.01),
            hover: .easeOut(duration: 0.12),
            reveal: .easeOut(duration: 0.12),
            allowsAmbient: false,
            meshDrifts: false,
            reduceMotion: true,
            reduceTransparency: reduceTransparency
        )
    }
}

extension EnvironmentValues {
    @Entry var motion: MotionTokens = .standard
}

extension View {
    /// Install resolved motion tokens at a scene root.
    func resolvedMotion(reduceMotion: Bool, reduceTransparency: Bool) -> some View {
        environment(\.motion, .resolve(reduceMotion: reduceMotion, reduceTransparency: reduceTransparency))
    }
}
