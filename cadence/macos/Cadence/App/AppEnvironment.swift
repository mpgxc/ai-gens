import SwiftUI
import Observation

/// The composition root: builds every service, wires them together, and is the
/// single object injected into the view tree.
@MainActor
@Observable
final class AppEnvironment {

    let settings: AppSettings
    let engine: TimerEngine
    let history: HistoryStore
    let ticker = MenuBarTicker()
    let iconRenderer = StatusIconRenderer()
    let notifications = NotificationService()
    let sound = SoundService()
    let music = MusicPlayer()

    @ObservationIgnored private let activity = ActivityToken()
    @ObservationIgnored private let power = PowerEventsService()
    @ObservationIgnored private let file: HistoryFileStore

    init() {
        let file = HistoryFileStore()
        let settings = AppSettings()
        self.file = file
        self.settings = settings
        self.history = HistoryStore(file: file)
        self.engine = TimerEngine(config: settings.timerConfig)

        wireEffects()
        settings.onChange = { [weak self] in self?.applySettings() }
        applySettings()
    }

    // MARK: - Startup

    func bootstrap() async {
        await history.load()
        await notifications.bootstrap()

        notifications.onAction = { [weak self] action in
            guard let self else { return }
            switch action {
            case .startNext: engine.start()
            case .skip:      skip()
            case .extend:    engine.extend(by: .seconds(5 * 60))
            }
        }

        // Restore an in-flight session; the engine applies the wake policy.
        if let state = await file.loadState() {
            engine.restore(state.snapshot())
            if let missed = engine.missedPhase {
                notifications.notifyMissed(phase: missed)
            }
        }

        ticker.start()

        power.start(
            onWake: { [weak self] in
                guard let self else { return }
                engine.reconcile()
                if let missed = engine.missedPhase {
                    notifications.notifyMissed(phase: missed)
                }
            },
            onSleep: { [weak self] in
                guard let self else { return }
                Task { await self.history.flush() }
            }
        )
    }

    /// Called on `willTerminate` — the debounced save must not be the last word.
    func shutdown() async {
        await history.flush()
        music.stopImmediately()   // also closes the security-scoped file access
        power.stop()
        ticker.stop()
    }

    // MARK: - Actions

    func skip() {
        sound.tick()
        engine.skip()
    }

    // MARK: - Wiring

    private func wireEffects() {
        engine.attach(effects: TimerEffects(
            record: { [history] session in
                history.append(session)
            },
            scheduleAlert: { [notifications] phase, deadline in
                notifications.schedule(phase: phase, at: deadline)
            },
            cancelAlerts: { [notifications] in
                notifications.cancelAll()
            },
            chime: { [sound] phase in
                sound.chime(for: phase)
                sound.haptic()
            },
            setBusy: { [activity] busy in
                activity.setBusy(busy)
            },
            setMusicPlaying: { [music] playing in
                playing ? music.start() : music.fadeOutAndStop()
            },
            persistState: { [file] snapshot in
                let state = PersistedState(snapshot)
                Task { await file.saveState(state) }
            }
        ))
    }

    private func applySettings() {
        engine.config = settings.timerConfig
        sound.setEnabled(settings.soundEnabled)
        activity.setPreventsSleep(settings.preventSleepDuringFocus)
        music.configure(
            source: settings.musicSource,
            volume: settings.musicVolume,
            shuffle: settings.musicShuffle
        )
    }
}
