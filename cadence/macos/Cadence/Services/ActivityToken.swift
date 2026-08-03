import Foundation

/// Keeps App Nap away while a phase is actually running.
///
/// This matters more than it looks: an `LSUIElement` app with no visible
/// window is a prime nap candidate, and a napped process runs its timers late.
/// The token is held for exactly the lifetime of a running phase and released
/// on pause, completion and idle.
///
/// `.idleSystemSleepDisabled` is opt-in via a setting rather than always on —
/// silently preventing a laptop from sleeping would be hostile, and the
/// pre-scheduled notification already guarantees punctuality.
@MainActor
final class ActivityToken {

    private var token: NSObjectProtocol?
    private var preventsSleep = false

    func setPreventsSleep(_ preventsSleep: Bool) {
        guard preventsSleep != self.preventsSleep else { return }
        self.preventsSleep = preventsSleep
        if token != nil { begin() }   // re-acquire with the new options
    }

    func setBusy(_ busy: Bool) {
        busy ? begin() : end()
    }

    private func begin() {
        end()
        var options: ProcessInfo.ActivityOptions = [.userInitiated]
        if preventsSleep { options.insert(.idleSystemSleepDisabled) }
        token = ProcessInfo.processInfo.beginActivity(
            options: options,
            reason: "Cadence focus timer running"
        )
    }

    private func end() {
        if let token { ProcessInfo.processInfo.endActivity(token) }
        token = nil
    }

    deinit {
        if let token { ProcessInfo.processInfo.endActivity(token) }
    }
}
