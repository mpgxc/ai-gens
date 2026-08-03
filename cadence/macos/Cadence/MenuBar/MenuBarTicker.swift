import Foundation
import Observation

/// A 1 Hz heartbeat, observed by the status label and nothing else.
///
/// This is the one surface in the app that *must* push state, because the
/// status item cannot host a `TimelineView`. Everything visible inside a
/// window derives its own value per frame instead.
///
/// The timer is scheduled in `.common` run loop mode so it keeps firing while
/// a menu is tracking, and given generous tolerance so the system can coalesce
/// it with other wakeups.
@MainActor
@Observable
final class MenuBarTicker {

    private(set) var tick: Int = 0

    @ObservationIgnored private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        // Align to the next whole second so the displayed value changes at the
        // same moment the underlying countdown does.
        let now = Date()
        let fireAt = now.addingTimeInterval(1 - now.timeIntervalSince1970.truncatingRemainder(dividingBy: 1))

        let timer = Timer(fire: fireAt, interval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick &+= 1 }
        }
        timer.tolerance = 0.15
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit { timer?.invalidate() }
}
