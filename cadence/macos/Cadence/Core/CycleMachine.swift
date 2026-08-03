import Foundation

/// Pure transition rules for the focus/break cycle.
///
/// Kept separate from `TimerEngine` so the ordering logic can be reasoned
/// about (and tested) without any clocks, tasks or actors involved.
enum CycleMachine {

    /// The phase that follows `phase`, given how many focus blocks have been
    /// completed *including* the one that just finished.
    static func phase(after phase: Phase, completedFocusCount: Int, config: TimerConfig) -> Phase {
        guard phase == .focus else { return .focus }
        let every = max(1, config.longBreakEvery)
        return completedFocusCount % every == 0 ? .longBreak : .shortBreak
    }

    /// Position within the current cycle, 1-based, for the cycle pips.
    /// A long break resets the count, so this always reads 1...longBreakEvery.
    static func cyclePosition(completedFocusCount: Int, config: TimerConfig) -> Int {
        let every = max(1, config.longBreakEvery)
        return completedFocusCount % every + 1
    }
}
