import SwiftUI

@main
struct CadenceApp: App {

    @State private var env = AppEnvironment()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some Scene {
        MenuBarExtra {
            PanelView(env: env)
                .environment(env)
                .resolvedMotion(reduceMotion: reduceMotion, reduceTransparency: reduceTransparency)
                .task { await env.bootstrap() }
        } label: {
            StatusLabelView(
                engine: env.engine,
                ticker: env.ticker,
                renderer: env.iconRenderer,
                style: env.settings.menuBarStyle,
                coloured: env.settings.colouredMenuBarIcon
            )
        }
        .menuBarExtraStyle(.window)

        MainWindow(env: env)
            .commands { CadenceCommands(env: env) }

        Settings {
            SettingsView(env: env)
                .environment(env)
                .resolvedMotion(reduceMotion: reduceMotion, reduceTransparency: reduceTransparency)
        }
    }
}

/// Menu commands. `LSUIElement` hides the app menu until a window is open, so
/// these are reachable exactly when they are useful.
struct CadenceCommands: Commands {
    let env: AppEnvironment

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button(env.engine.snapshot.isRunning ? "Pause" : "Start") {
                env.engine.toggle()
            }
            .keyboardShortcut(.space, modifiers: [.command, .shift])

            Button("Skip Phase") { env.skip() }
                .keyboardShortcut("s", modifiers: [.command, .shift])

            Button("Stop Session") { env.engine.stop() }
                .keyboardShortcut(".", modifiers: .command)

            Divider()

            Button("Add 5 Minutes") { env.engine.extend(by: .seconds(5 * 60)) }
                .keyboardShortcut("t", modifiers: [.command, .shift])
        }

        // Nothing here needs a Help book yet, and an empty one is worse than none.
        CommandGroup(replacing: .help) { }
    }
}
