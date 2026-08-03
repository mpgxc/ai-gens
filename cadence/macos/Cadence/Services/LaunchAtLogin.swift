import Foundation
import ServiceManagement

/// Launch-at-login via `SMAppService`. No entitlement, works sandboxed, and
/// table stakes for a menu bar app that is supposed to already be there.
enum LaunchAtLogin {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                // `.requiresApproval` means the user disabled it in System
                // Settings; re-registering would silently fail, so leave it.
                guard SMAppService.mainApp.status != .enabled else { return }
                try SMAppService.mainApp.register()
            } else {
                guard SMAppService.mainApp.status == .enabled else { return }
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Cadence: launch-at-login change failed: \(error.localizedDescription)")
        }
    }
}
