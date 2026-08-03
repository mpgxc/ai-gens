import Foundation
import Observation

/// Side effects the engine triggers, injected so `Core` stays free of
/// notification/audio/AppKit dependencies and remains testable headlessly.
@MainActor
struct TimerEffects {
    var record: (FocusSession) -> Void = { _ in }
    /// Pre-schedule an alert at the deadline. Doing this up front means the
    /// user is notified on time even if the process gets napped and our
    /// completion task runs late.
    var scheduleAlert: (Phase, Date) -> Void = { _, _ in }
    var cancelAlerts: () -> Void = {}
    var chime: (Phase) -> Void = { _ in }
    /// Holds/releases the `ProcessInfo` activity that keeps App Nap away
    /// while a phase is actually running.
    var setBusy: (Bool) -> Void = { _ in }
    var persistState: (TimerSnapshot) -> Void = { _ in }
}

/// Owns the timer's state machine and its one armed completion task.
///
/// Design notes that matter:
/// * Nothing polls. Exactly one `Task.sleep(until:clock:.continuous)` is armed
///   per running phase, and it is cancelled on every state change.
/// * `ContinuousClock` (not `SuspendingClock`) keeps counting through system
///   sleep, and is immune to NTP corrections and the user changing the clock.
/// * `runToken` makes completion idempotent, so a late task from a phase the
///   user already skipped can never advance the cycle a second time.
@MainActor
@Observable
final class TimerEngine {

    enum CompletionReason: Sendable {
        case reachedDeadline
        case skipped
        case stopped
        /// The deadline passed while the Mac was asleep, by more than the grace window.
        case missedWhileAsleep
    }

    private(set) var snapshot: TimerSnapshot
    var config: TimerConfig {
        didSet { if snapshot.isIdle { resetPlannedForIdlePhase() } }
    }

    /// Set when a phase elapsed during sleep so the UI can explain itself
    /// instead of silently jumping ahead. Cleared on the next user action.
    private(set) var missedPhase: Phase?

    /// If a phase finished but its successor does not auto-start, the engine
    /// parks here: armed on the next phase, waiting for a nudge.
    private(set) var awaitingStart = false

    private var effects: TimerEffects
    private var completionTask: Task<Void, Never>?
    private var runToken = 0
    private var pausedAt: ContinuousClock.Instant?

    /// How far past a deadline still counts as "the user was basically there".
    /// Beyond this we assume the Mac slept through the whole phase.
    private static let wakeGrace: Duration = .seconds(120)

    init(config: TimerConfig = .standard, effects: TimerEffects = TimerEffects()) {
        self.config = config
        self.effects = effects
        self.snapshot = .idle(phase: .focus, config: config)
    }

    func attach(effects: TimerEffects) { self.effects = effects }

    // MARK: - Derived

    var cyclePosition: Int {
        CycleMachine.cyclePosition(completedFocusCount: snapshot.completedFocusCount, config: config)
    }

    var sessionName: String {
        get { snapshot.sessionName }
        set { snapshot.sessionName = newValue; effects.persistState(snapshot) }
    }

    // MARK: - Commands

    func start() {
        guard !snapshot.isRunning else { return }
        missedPhase = nil
        awaitingStart = false

        if snapshot.isIdle { snapshot.startedAt = Date() }
        let remaining = snapshot.isPaused
            ? Duration.seconds(snapshot.remaining(at: Date()))
            : snapshot.planned

        if let pausedAt {
            snapshot.accumulatedPause += ContinuousClock.now - pausedAt
            self.pausedAt = nil
        }
        run(for: remaining)
    }

    func pause() {
        guard case .running = snapshot.run else { return }
        let remaining = Duration.seconds(snapshot.remaining(at: Date()))
        cancelArmed()
        pausedAt = ContinuousClock.now
        snapshot.run = .paused(remaining: remaining)
        effects.cancelAlerts()
        effects.setBusy(false)
        effects.persistState(snapshot)
    }

    func toggle() { snapshot.isRunning ? pause() : start() }

    /// End this phase early and move on. Recorded as not completed.
    func skip() { finish(reason: .skipped, endedAt: Date()) }

    /// Abandon the session entirely and return to an idle focus block.
    func stop() {
        if snapshot.startedAt != nil, !snapshot.isIdle {
            recordSession(endedAt: Date(), completed: false)
        }
        cancelArmed()
        effects.cancelAlerts()
        effects.setBusy(false)
        missedPhase = nil
        awaitingStart = false
        pausedAt = nil
        snapshot = .idle(phase: .focus, config: config)
        effects.persistState(snapshot)
    }

    /// Add time to the phase in flight — the "five more minutes" affordance.
    func extend(by extra: Duration) {
        guard case .running = snapshot.run else {
            if case .paused(let remaining) = snapshot.run {
                snapshot.planned += extra
                snapshot.run = .paused(remaining: remaining + extra)
            }
            return
        }
        let remaining = Duration.seconds(snapshot.remaining(at: Date())) + extra
        snapshot.planned += extra
        run(for: remaining)
    }

    // MARK: - Lifecycle reconciliation

    /// Re-evaluate after waking, or after the app was relaunched with an
    /// in-flight session restored from disk.
    func reconcile() {
        guard case .running(let deadline, let instant) = snapshot.run else { return }
        let now = ContinuousClock.now

        guard now >= instant else {
            // Still in the future — the armed task may have been torn down by
            // sleep, so arm a fresh one.
            arm(until: instant)
            return
        }

        let overshoot = now - instant
        // Finish the phase *at its deadline*, not at wake time, so history
        // never claims a 25-minute block took three hours.
        finish(
            reason: overshoot > Self.wakeGrace ? .missedWhileAsleep : .reachedDeadline,
            endedAt: deadline
        )
    }

    /// Restore an in-flight phase persisted before quit/sleep.
    func restore(_ restored: TimerSnapshot) {
        snapshot = restored
        if case .running = restored.run { reconcile() }
    }

    // MARK: - Internals

    private func run(for remaining: Duration) {
        let instant = ContinuousClock.now.advanced(by: remaining)
        let deadline = Date().addingTimeInterval(remaining.seconds)
        snapshot.run = .running(deadline: deadline, instant: instant)
        if snapshot.startedAt == nil { snapshot.startedAt = Date() }

        effects.cancelAlerts()
        effects.scheduleAlert(snapshot.phase, deadline)
        effects.setBusy(true)
        effects.persistState(snapshot)
        arm(until: instant)
    }

    private func arm(until instant: ContinuousClock.Instant) {
        completionTask?.cancel()
        runToken &+= 1
        let token = runToken
        completionTask = Task { [weak self] in
            try? await Task.sleep(until: instant, clock: .continuous)
            guard !Task.isCancelled else { return }
            self?.finish(reason: .reachedDeadline, endedAt: Date(), token: token)
        }
    }

    private func cancelArmed() {
        completionTask?.cancel()
        completionTask = nil
        runToken &+= 1
    }

    /// The single funnel every phase ending goes through.
    private func finish(reason: CompletionReason, endedAt: Date, token: Int? = nil) {
        // Reject a late task belonging to a phase that has already moved on.
        if let token, token != runToken { return }
        guard !snapshot.isIdle else { return }

        cancelArmed()
        effects.cancelAlerts()
        effects.setBusy(false)

        let didComplete = (reason == .reachedDeadline || reason == .missedWhileAsleep)
        recordSession(endedAt: endedAt, completed: didComplete)

        let finished = snapshot.phase
        var completedFocus = snapshot.completedFocusCount
        if finished == .focus, didComplete { completedFocus += 1 }

        let next = CycleMachine.phase(after: finished, completedFocusCount: completedFocus, config: config)

        if reason == .missedWhileAsleep {
            missedPhase = finished
        } else if reason == .reachedDeadline {
            effects.chime(finished)
        }

        snapshot = TimerSnapshot(
            phase: next,
            planned: config.duration(for: next),
            run: .idle,
            completedFocusCount: completedFocus,
            // A break carries no session name; a new focus block keeps the
            // previous one so a multi-block task doesn't need retyping.
            sessionName: next.isBreak ? "" : snapshot.sessionName,
            startedAt: nil,
            accumulatedPause: .zero
        )
        pausedAt = nil

        // Never auto-start into a phase the user physically was not present
        // for — that would silently burn a break they never took.
        let shouldAutoStart = reason != .missedWhileAsleep
            && reason != .stopped
            && config.autoStarts(next)

        if shouldAutoStart {
            start()
        } else {
            awaitingStart = reason != .stopped
            effects.persistState(snapshot)
        }
    }

    private func recordSession(endedAt: Date, completed: Bool) {
        guard let startedAt = snapshot.startedAt else { return }
        var pause = snapshot.accumulatedPause
        if let pausedAt { pause += ContinuousClock.now - pausedAt }

        effects.record(
            FocusSession(
                phase: snapshot.phase,
                name: snapshot.sessionName,
                startedAt: startedAt,
                endedAt: max(endedAt, startedAt),
                planned: snapshot.planned.seconds,
                pausedTotal: pause.seconds,
                completed: completed
            )
        )
    }

    private func resetPlannedForIdlePhase() {
        snapshot.planned = config.duration(for: snapshot.phase)
    }
}
