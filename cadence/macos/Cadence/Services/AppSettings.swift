import Foundation
import Observation

enum MenuBarStyle: String, CaseIterable, Identifiable, Sendable {
    case ringAndTime, ringOnly, timeOnly
    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .ringAndTime: "Ring and time"
        case .ringOnly:    "Ring only"
        case .timeOnly:    "Time only"
        }
    }

    var showsRing: Bool { self != .timeOnly }
    var showsTime: Bool { self != .ringOnly }
}

/// Every preference, and the single place their `UserDefaults` keys are spelled.
///
/// Stored properties (not computed) so `@Observable` actually tracks them;
/// each one writes through on change.
@MainActor
@Observable
final class AppSettings {

    enum Key: String {
        case focusMinutes, shortBreakMinutes, longBreakMinutes, longBreakEvery
        case autoStartBreaks, autoStartFocus
        case menuBarStyle, colouredMenuBarIcon
        case soundEnabled, launchAtLogin, preventSleepDuringFocus
    }

    var focusMinutes: Int          { didSet { write(.focusMinutes, focusMinutes) } }
    var shortBreakMinutes: Int     { didSet { write(.shortBreakMinutes, shortBreakMinutes) } }
    var longBreakMinutes: Int      { didSet { write(.longBreakMinutes, longBreakMinutes) } }
    var longBreakEvery: Int        { didSet { write(.longBreakEvery, longBreakEvery) } }
    var autoStartBreaks: Bool      { didSet { write(.autoStartBreaks, autoStartBreaks) } }
    var autoStartFocus: Bool       { didSet { write(.autoStartFocus, autoStartFocus) } }
    var menuBarStyle: MenuBarStyle { didSet { write(.menuBarStyle, menuBarStyle.rawValue) } }

    /// Off by default: a template (monochrome) status item is what macOS
    /// expects, survives menu bar tinting, and does not look broken while the
    /// item is highlighted. Phase is conveyed by the arc's shape instead.
    var colouredMenuBarIcon: Bool  { didSet { write(.colouredMenuBarIcon, colouredMenuBarIcon) } }

    var soundEnabled: Bool         { didSet { write(.soundEnabled, soundEnabled) } }
    var preventSleepDuringFocus: Bool { didSet { write(.preventSleepDuringFocus, preventSleepDuringFocus) } }

    var launchAtLogin: Bool {
        didSet {
            write(.launchAtLogin, launchAtLogin)
            LaunchAtLogin.set(launchAtLogin)
        }
    }

    /// Called after any preference changes, so `AppEnvironment` can push a
    /// fresh `TimerConfig` into the engine without a polling observer.
    /// `didSet` does not fire during `init`, so this never runs mid-setup.
    @ObservationIgnored var onChange: (() -> Void)?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let standard = TimerConfig.standard

        func int(_ key: Key, _ fallback: Int) -> Int {
            defaults.object(forKey: key.rawValue) == nil ? fallback : defaults.integer(forKey: key.rawValue)
        }
        func bool(_ key: Key, _ fallback: Bool) -> Bool {
            defaults.object(forKey: key.rawValue) == nil ? fallback : defaults.bool(forKey: key.rawValue)
        }

        focusMinutes      = int(.focusMinutes, Int(standard.focus.seconds / 60))
        shortBreakMinutes = int(.shortBreakMinutes, Int(standard.shortBreak.seconds / 60))
        longBreakMinutes  = int(.longBreakMinutes, Int(standard.longBreak.seconds / 60))
        longBreakEvery    = int(.longBreakEvery, standard.longBreakEvery)
        autoStartBreaks   = bool(.autoStartBreaks, standard.autoStartBreaks)
        autoStartFocus    = bool(.autoStartFocus, standard.autoStartFocus)
        soundEnabled      = bool(.soundEnabled, true)
        colouredMenuBarIcon = bool(.colouredMenuBarIcon, false)
        preventSleepDuringFocus = bool(.preventSleepDuringFocus, false)
        launchAtLogin     = bool(.launchAtLogin, false)
        menuBarStyle      = MenuBarStyle(rawValue: defaults.string(forKey: Key.menuBarStyle.rawValue) ?? "")
            ?? .ringAndTime
    }

    /// The value type the engine actually consumes.
    var timerConfig: TimerConfig {
        TimerConfig(
            focus: TimerConfig.clamp(focusMinutes),
            shortBreak: TimerConfig.clamp(shortBreakMinutes),
            longBreak: TimerConfig.clamp(longBreakMinutes),
            longBreakEvery: max(1, min(12, longBreakEvery)),
            autoStartBreaks: autoStartBreaks,
            autoStartFocus: autoStartFocus
        )
    }

    private func write(_ key: Key, _ value: Any) {
        defaults.set(value, forKey: key.rawValue)
        onChange?()
    }
}
