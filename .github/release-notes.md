A focus timer that lives in your menu bar. Native macOS, built on Liquid Glass.

### Install

Every release ships two identical disk images: `Cadence-<version>.dmg` for the
archive, and `Cadence.dmg` under a fixed name so this URL always resolves to the
newest build and never has to be updated:

<https://github.com/mpgxc/ai-gens/releases/latest/download/Cadence.dmg>

Download it, drag Cadence to **Applications**, then run:

```
xattr -dr com.apple.quarantine /Applications/Cadence.app
```

Do this before the first launch. Cadence is only **ad-hoc signed** — proper
signing needs a Developer ID certificate this repository does not have — so
macOS quarantines it on download and refuses to open it. The command clears
that one flag and nothing else; it does not disable any system-wide security
setting.

It has to run against the copy in Applications, not the one on the mounted disk
image, which is read-only. If it reports a permissions error, prefix it with
`sudo`.

The Settings route works too: try to open Cadence, then go to **System Settings
→ Privacy & Security** and click **Open Anyway**. Right-click → *Open* used to
be the trick for this, but macOS 15 removed it — don't waste time on it.

Requires **macOS 26 Tahoe or later** — the interface is built on `glassEffect`
and `GlassEffectContainer`, which do not exist on earlier versions.

### Build it yourself

```
brew install xcodegen
cd cadence/macos && xcodegen generate && open Cadence.xcodeproj
```

Set a development team before running: `UNUserNotificationCenter` requires a
signed bundle, and a free personal team is enough.

### What it does

Deadline-accurate Pomodoro timer, session names, recurring breaks with a long
break every fourth block, statistics by day/week/month, native notifications,
and a menu bar item showing a live progress ring and countdown. English and
Português. No account, no ads, no telemetry — sessions are a plain JSON file on
your Mac.

Full details: [`cadence/README.md`](https://github.com/mpgxc/ai-gens/blob/main/cadence/README.md)
