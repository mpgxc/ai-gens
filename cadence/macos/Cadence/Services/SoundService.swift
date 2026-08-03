import AppKit

/// Phase-transition chimes, drawn from the system sound set so the app ships
/// no audio assets and always matches the user's output device.
@MainActor
final class SoundService {

    private var enabled: Bool = true
    private var cache: [String: NSSound] = [:]

    func setEnabled(_ enabled: Bool) { self.enabled = enabled }

    /// Played when `phase` *ends*. Focus ending is the moment worth marking,
    /// so it gets the brighter sound.
    func chime(for phase: Phase) {
        guard enabled else { return }
        play(named: phase == .focus ? "Glass" : "Submarine")
    }

    /// A quieter tick for manual actions like skip.
    func tick() {
        guard enabled else { return }
        play(named: "Tink")
    }

    private func play(named name: String) {
        let sound = cache[name] ?? NSSound(named: name)
        guard let sound else { return }
        cache[name] = sound
        if sound.isPlaying { sound.stop() }
        sound.play()
    }

    /// Force Touch trackpads get a physical bump at phase boundaries; every
    /// other Mac silently ignores this.
    func haptic() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
}
