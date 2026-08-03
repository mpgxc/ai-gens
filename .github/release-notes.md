A focus timer that lives in your menu bar. Native macOS, built on Liquid Glass.

### Install

Download the `.dmg` below and drag Cadence to Applications.

**The app is unsigned**, so macOS will refuse to open it the first time. This is
expected: signing requires a Developer ID certificate that this repository does
not have. Either right-click the app → **Open** → **Open**, or clear the
quarantine flag:

```
xattr -dr com.apple.quarantine /Applications/Cadence.app
```

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
