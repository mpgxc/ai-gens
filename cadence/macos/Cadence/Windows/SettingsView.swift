import SwiftUI

struct SettingsView: View {
    let env: AppEnvironment

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") { GeneralSettings(env: env) }
            Tab("Timer", systemImage: "timer") { TimerSettings(env: env) }
            Tab("Menu Bar", systemImage: "menubar.rectangle") { MenuBarSettings(env: env) }
        }
        .frame(width: 460, height: 320)
    }
}

private struct TimerSettings: View {
    let env: AppEnvironment
    private var settings: AppSettings { env.settings }

    var body: some View {
        Form {
            Section {
                minutes("Focus", value: Binding(
                    get: { settings.focusMinutes },
                    set: { settings.focusMinutes = $0 }
                ))
                minutes("Short break", value: Binding(
                    get: { settings.shortBreakMinutes },
                    set: { settings.shortBreakMinutes = $0 }
                ))
                minutes("Long break", value: Binding(
                    get: { settings.longBreakMinutes },
                    set: { settings.longBreakMinutes = $0 }
                ))
                Stepper(
                    "Long break every \(settings.longBreakEvery) focus blocks",
                    value: Binding(get: { settings.longBreakEvery }, set: { settings.longBreakEvery = $0 }),
                    in: 2...12
                )
            } footer: {
                Text("Phases are capped at 59 minutes so the menu bar countdown never changes width.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Start breaks automatically", isOn: Binding(
                    get: { settings.autoStartBreaks },
                    set: { settings.autoStartBreaks = $0 }
                ))
                Toggle("Start the next focus block automatically", isOn: Binding(
                    get: { settings.autoStartFocus },
                    set: { settings.autoStartFocus = $0 }
                ))
            }
        }
        .formStyle(.grouped)
    }

    private func minutes(_ title: LocalizedStringResource, value: Binding<Int>) -> some View {
        Stepper(value: value, in: 1...59) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue) min")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct GeneralSettings: View {
    let env: AppEnvironment
    private var settings: AppSettings { env.settings }

    @State private var isExporting = false

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.launchAtLogin = $0 }
                ))
                Toggle("Play a sound at phase changes", isOn: Binding(
                    get: { settings.soundEnabled },
                    set: { settings.soundEnabled = $0 }
                ))
                Toggle("Keep the Mac awake during focus", isOn: Binding(
                    get: { settings.preventSleepDuringFocus },
                    set: { settings.preventSleepDuringFocus = $0 }
                ))
            }

            Section {
                LabeledContent("Sessions recorded") {
                    Text("\(env.history.sessions.count)").monospacedDigit()
                }
                Button("Export history…") { isExporting = true }
            } footer: {
                Text("Your sessions are a plain JSON file in Application Support. Nothing is uploaded anywhere.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !env.notifications.isAuthorized {
                Section {
                    Button("Allow notifications") {
                        Task { await env.notifications.requestAuthorization() }
                    }
                } footer: {
                    Text("Without permission, Cadence can still chime but cannot show phase-end alerts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .fileExporter(
            isPresented: $isExporting,
            document: HistoryDocument(sessions: env.history.sessions),
            contentType: .json,
            defaultFilename: "cadence-sessions"
        ) { _ in }
    }
}

private struct MenuBarSettings: View {
    let env: AppEnvironment
    private var settings: AppSettings { env.settings }

    var body: some View {
        Form {
            Section {
                Picker("Show", selection: Binding(
                    get: { settings.menuBarStyle },
                    set: { settings.menuBarStyle = $0 }
                )) {
                    ForEach(MenuBarStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                Toggle("Use the phase colour", isOn: Binding(
                    get: { settings.colouredMenuBarIcon },
                    set: { settings.colouredMenuBarIcon = $0 }
                ))
            } footer: {
                Text("A monochrome icon is the macOS default: it adapts to light and dark, survives menu bar tinting, and stays legible while highlighted. Focus and break are told apart by the arc — solid for focus, dashed for a break — so colour is never the only signal.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
