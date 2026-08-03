import Foundation

/// The three kinds of interval a Pomodoro cycle alternates between.
///
/// Deliberately `Sendable` and free of any UI import: everything in `Core`
/// must be usable from any isolation domain.
enum Phase: String, Codable, CaseIterable, Sendable, Hashable {
    case focus
    case shortBreak
    case longBreak

    var isBreak: Bool { self != .focus }

    /// SF Symbol used in notifications, the history list and the status item's
    /// paused glyph.
    var symbolName: String {
        switch self {
        case .focus:      "brain.head.profile"
        case .shortBreak: "cup.and.saucer.fill"
        case .longBreak:  "figure.walk"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .focus:      "Focus"
        case .shortBreak: "Short break"
        case .longBreak:  "Long break"
        }
    }

    /// Copy shown when this phase *ends*.
    var completionMessage: LocalizedStringResource {
        switch self {
        case .focus:      "Focus block done. Time to step away."
        case .shortBreak: "Break's over — back to it."
        case .longBreak:  "Long break's over. Ready for another cycle?"
        }
    }
}
