import SwiftUI

/// The full window: the session hero, history and stats.
///
/// Opened from the panel (or ⌘0) rather than at launch — `LSUIElement` means
/// the app is menu-bar-first and has no Dock icon to click.
struct MainWindow: Scene {
    static let identifier = "cadence.main"

    let env: AppEnvironment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some Scene {
        Window("Cadence", id: Self.identifier) {
            MainWindowContent(env: env)
                .environment(env)
                .resolvedMotion(reduceMotion: reduceMotion, reduceTransparency: reduceTransparency)
                .frame(minWidth: 620, minHeight: 560)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 720, height: 620)
        .windowBackgroundDragBehavior(.enabled)
        .keyboardShortcut("0", modifiers: .command)
    }
}

private struct MainWindowContent: View {
    let env: AppEnvironment

    enum Pane: String, CaseIterable, Identifiable {
        case session, history, stats
        var id: String { rawValue }
        var title: LocalizedStringResource {
            switch self {
            case .session: "Session"
            case .history: "History"
            case .stats:   "Stats"
            }
        }
        var symbol: String {
            switch self {
            case .session: "timer"
            case .history: "list.bullet"
            case .stats:   "chart.bar"
            }
        }
    }

    @State private var pane: Pane = .session
    @Environment(\.motion) private var motion

    var body: some View {
        ZStack {
            // The window's own backdrop. Glass controls in the toolbar sample
            // this, which is the correct direction — content below, glass above.
            PhaseMesh(phase: env.engine.snapshot.phase)
                .opacity(motion.reduceTransparency ? 1 : 0.55)
                .ignoresSafeArea()

            Group {
                switch pane {
                case .session: SessionPane(env: env)
                case .history: HistoryPane(env: env)
                case .stats:   StatsPane(env: env)
                }
            }
            .transition(.blurReplace)
        }
        .animation(motion.reveal, value: pane)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("View", selection: $pane) {
                    ForEach(Pane.allCases) { p in
                        Label(String(localized: p.title), systemImage: p.symbol).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 260)
            }
        }
        .containerBackground(.thinMaterial, for: .window)
    }
}
