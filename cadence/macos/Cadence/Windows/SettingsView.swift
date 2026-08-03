import SwiftUI
import UniformTypeIdentifiers   // UTType.audio / .folder for the music picker

struct SettingsView: View {
    let env: AppEnvironment

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") { GeneralSettings(env: env) }
            Tab("Timer", systemImage: "timer") { TimerSettings(env: env) }
            Tab("Music", systemImage: "music.note") { MusicSettings(env: env) }
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

/// Focus music.
///
/// Two sources on purpose. A local file or folder is the common case and works
/// offline; a stream URL covers "leave a radio on", which is what most people
/// actually mean. There is no YouTube option because their terms forbid pulling
/// the audio out, and the only sanctioned embed needs a visible player — which a
/// menu bar timer does not have.
private struct MusicSettings: View {
    let env: AppEnvironment
    private var settings: AppSettings { env.settings }

    @State private var isPicking = false

    var body: some View {
        Form {
            Section {
                Picker("Play during focus", selection: Binding(
                    get: { settings.musicSourceKind },
                    set: { settings.musicSourceKind = $0 }
                )) {
                    ForEach(MusicSourceKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }

                if settings.musicSourceKind.needsBookmark {
                    LabeledContent(settings.musicSourceKind == .folder ? "Folder" : "Track") {
                        HStack(spacing: 8) {
                            Text(chosenName)
                                .foregroundStyle(settings.musicBookmark == nil ? .tertiary : .secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Button("Choose…") { isPicking = true }
                        }
                    }
                }

                if settings.musicSourceKind == .stream {
                    LabeledContent("URL") {
                        TextField(
                            text: Binding(get: { settings.musicStreamURL },
                                          set: { settings.musicStreamURL = $0 }),
                            prompt: Text("https://example.com/stream.mp3")
                        ) { EmptyView() }
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 240)
                    }
                }

                if settings.musicSourceKind == .folder {
                    Toggle("Shuffle", isOn: Binding(
                        get: { settings.musicShuffle },
                        set: { settings.musicShuffle = $0 }
                    ))
                }
            } footer: {
                Text("Music starts when a focus block starts and fades out when it ends — breaks stay quiet. A single track loops; a folder plays through.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if settings.musicSourceKind != .off {
                Section {
                    LabeledContent("Volume") {
                        Slider(
                            value: Binding(get: { settings.musicVolume },
                                           set: { settings.musicVolume = $0 }),
                            in: 0...1
                        )
                        .frame(minWidth: 180)
                    }
                    HStack {
                        Button("Preview") { env.music.preview() }
                        Spacer()
                        statusLabel
                    }
                } footer: {
                    Text("A volume change takes effect on the next focus block, so it never jumps mid-session.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .fileImporter(
            isPresented: $isPicking,
            allowedContentTypes: settings.musicSourceKind == .folder ? [.folder] : [.audio],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            // Persist a bookmark, not a path: inside the sandbox the path stops
            // resolving after relaunch.
            settings.musicBookmark = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }
    }

    private var chosenName: String {
        switch settings.musicSource {
        case .file(let url), .folder(let url): url.lastPathComponent
        default: String(localized: "Nothing chosen")
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch env.music.status {
        case .idle:
            EmptyView()
        case .playing(let name):
            Label(name, systemImage: "waveform")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
                .lineLimit(2)
        }
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
