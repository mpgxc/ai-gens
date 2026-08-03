import Foundation
import UserNotifications

/// Phase-end alerts.
///
/// Notifications are **pre-scheduled at the deadline** rather than posted when
/// the engine's completion task fires. If the process gets napped, the system
/// still delivers on time — the alert is the user's real guarantee, the task
/// is only the app's bookkeeping.
///
/// Note for first run: `UNUserNotificationCenter` requires a signed app bundle.
/// Launch the app target from Xcode with a development team set; a bare binary
/// traps with "bundleProxyForCurrentProcess is nil".
@MainActor
final class NotificationService: NSObject {

    enum Action: String {
        case startNext = "cadence.startNext"
        case skip      = "cadence.skip"
        case extend    = "cadence.extend"
    }

    static let categoryIdentifier = "cadence.phaseEnded"
    private static let requestIdentifier = "cadence.phaseEnd"

    private let center = UNUserNotificationCenter.current()
    private(set) var isAuthorized = false

    /// Wired up by `AppEnvironment` so a notification action can drive the engine.
    var onAction: ((Action) -> Void)?

    func bootstrap() async {
        center.delegate = self
        registerCategory()
        await requestAuthorization()
    }

    func requestAuthorization() async {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        isAuthorized = granted
    }

    private func registerCategory() {
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [
                UNNotificationAction(
                    identifier: Action.startNext.rawValue,
                    title: String(localized: "Start next"),
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: Action.extend.rawValue,
                    title: String(localized: "+5 minutes")
                ),
                UNNotificationAction(
                    identifier: Action.skip.rawValue,
                    title: String(localized: "Skip"),
                    options: [.destructive]
                ),
            ],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    /// Schedule the alert for the moment `phase` ends.
    func schedule(phase: Phase, at deadline: Date) {
        cancelAll()
        let delay = deadline.timeIntervalSinceNow
        guard delay > 0.5 else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: phase.title)
        content.body = String(localized: phase.completionMessage)
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier
        // `.timeSensitive` would pierce Focus modes, which suits a Pomodoro
        // app well, but it needs a paid-account entitlement. `.active` is the
        // honest default that works for everyone.
        content.interruptionLevel = .active

        let request = UNNotificationRequest(
            identifier: Self.requestIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        )
        center.add(request)
    }

    func cancelAll() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.requestIdentifier])
    }

    /// Fired when a phase elapsed while the Mac was asleep.
    func notifyMissed(phase: Phase) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: phase.title)
        content.body = String(localized: "This ended while your Mac was asleep. Nothing was started for you.")
        content.sound = nil
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {

    /// Show the banner even when Cadence is frontmost — the whole point is
    /// that the user is looking at something else.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let action = Action(rawValue: response.actionIdentifier) else { return }
        await MainActor.run { self.onAction?(action) }
    }
}
