import AppKit

/// Bridges sleep/wake into the engine's reconciliation path.
///
/// Swift 6 note: `Notification` is not `Sendable`, so the notification value is
/// mapped away at the boundary and only `Void` crosses the async sequence.
@MainActor
final class PowerEventsService {

    private var tasks: [Task<Void, Never>] = []

    /// - Parameters:
    ///   - onWake: recompute the deadline and apply the wake policy.
    ///   - onSleep: last chance to flush history and persist in-flight state.
    func start(onWake: @escaping @MainActor () -> Void,
               onSleep: @escaping @MainActor () -> Void) {
        stop()
        let center = NSWorkspace.shared.notificationCenter

        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            tasks.append(Task { @MainActor in
                for await _ in center.notifications(named: name).map({ _ in () }) {
                    onWake()
                }
            })
        }

        tasks.append(Task { @MainActor in
            for await _ in center.notifications(named: NSWorkspace.willSleepNotification).map({ _ in () }) {
                onSleep()
            }
        })
    }

    func stop() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
    }

    deinit { tasks.forEach { $0.cancel() } }
}
