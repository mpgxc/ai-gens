# Cadence

A focus timer that lives in your menu bar. Native macOS, built on Liquid Glass.

Two halves:

| | |
|---|---|
| `landing/index.html` | The landing page. One self-contained file, no build step, no external requests. |
| `macos/` | The SwiftUI app. macOS 26 (Tahoe) or later, Xcode 26, Swift 6. |

---

## Landing page

Open it. That's the whole workflow.

```bash
open cadence/landing/index.html
```

It is deliberately dependency-free: no `package.json`, no CDN, no webfont, no
images. Everything — the app mockups, the icon, the charts — is inline SVG and
CSS, and the hero timer is a real running state machine rather than a
screenshot.

A few implementation notes worth knowing before editing it:

- **Glass is four layers**, all of which work in Safari: `backdrop-filter`
  frost, a masked conic-gradient rim light that slowly rotates, an off-axis
  specular sheen, and inset/drop shadows. It has to look finished with just
  these.
- **SVG refraction is progressive enhancement only.** Safari and Firefox accept
  `backdrop-filter: url(#filter)` at parse time and then silently drop the SVG
  part, so `CSS.supports()` lies about it. The `feDisplacementMap` lens is
  gated behind a runtime check and is never load-bearing.
- **The capsule → cluster morph** uses the View Transitions API with a shared
  `view-transition-name`, which is the web's analogue of SwiftUI's
  `glassEffectID`. The root transition is suppressed so it stays a targeted
  morph rather than a page crossfade.
- **Reveals use `animation-timeline: view()`** — baseline in Safari 26, off the
  main thread. Browsers without it get the content immediately via
  `@supports not`.
- The **`60×` demo toggle** in the hero exists so you can watch a whole
  focus → break transition in about 25 seconds. The app itself runs in real
  minutes.

Both `prefers-color-scheme` and `prefers-reduced-motion` are fully handled;
reduced motion freezes the mesh, stops the rim light, and swaps state instantly
instead of morphing.

---

## macOS app

### Building

The repo ships an XcodeGen spec rather than a checked-in `.xcodeproj`, because a
`project.pbxproj` is a UUID-keyed plist that cannot be validated without a Mac —
one bad byte and Xcode refuses to open it with no useful diagnostic.

```bash
brew install xcodegen
cd cadence/macos
xcodegen generate
open Cadence.xcodeproj
```

**If XcodeGen isn't an option**, the manual path takes about a minute:
File ▸ New ▸ Project ▸ macOS ▸ App (SwiftUI), delete the generated Swift files,
drag `macos/Cadence/` in as a synchronised folder, then set: deployment target
26.0, Swift 6 with strict concurrency, `LSUIElement = YES`, App Sandbox on with
`Cadence.entitlements`, and the asset catalog's app icon name to `AppIcon`.

### Three things that will bite you on first build

1. **Set a development team.** `UNUserNotificationCenter` requires a signed app
   bundle — it traps with *"bundleProxyForCurrentProcess is nil"* otherwise. A
   free personal team is enough. Always run the app target from Xcode.
2. **The sandbox is on from day one, on purpose.** Turning it on later would
   relocate Application Support into a container and orphan the user's history.
   No extra entitlements are needed beyond user-selected files for export.
3. **There's no `Info.plist` file.** Xcode 26 generates it from build settings;
   `LSUIElement` and friends live in `project.yml`.

### How it's put together

```
macos/Cadence/
├── App/          composition root — CadenceApp, AppEnvironment
├── Core/         pure logic, no SwiftUI or AppKit: TimerEngine, Stats, …
├── Services/     persistence, notifications, sound, power events, App Nap
├── Design/       the design system and every animated primitive
├── MenuBar/      the status item and its glass panel
└── Windows/      session, history, stats, settings
```

Layer rule: `Core` imports nothing, `Services` imports `Core`, the view layers
import both, and nothing imports upward.

**The timer is a pure function of the clock.** `TimerSnapshot` stores an
absolute deadline and derives everything else; there is no accumulator anywhere,
so nothing can drift. Completion is one armed
`Task.sleep(until:clock:.continuous)` per phase, not a poll —
`ContinuousClock` keeps counting through system sleep and ignores NTP
corrections and clock changes. Views read `remaining(at:)` with the date their
`TimelineView` handed them, so the ring is continuous by construction rather
than stepping once per second.

**Sleep is handled explicitly.** On wake, a deadline that passed within two
minutes completes normally; anything older is recorded as finished *at its
deadline* and lands idle on the next phase instead of silently burning a break
the user was never present for.

**The menu bar drove several design decisions.** `MenuBarExtra`'s label only
accepts text and images — no custom views, and `.font()` is ignored — so the
ring is rendered through `ImageRenderer` into a template `NSImage`, quantised to
120 steps and cached, which makes a 25-minute session cost at most 120 renders.
The countdown is always zero-padded and monospaced so the item never changes
width. Phase is conveyed by the arc's *shape* (solid for focus, dashed for a
break), not colour, so it stays readable as a template image, while highlighted,
and with Differentiate Without Color on.

**Glass layering follows one rule: never stack glass on glass.** The system
already draws the panel's Liquid Glass, so the panel root adds nothing; inside
it an *opaque* mesh card provides content worth refracting, and only the
floating control cluster is glass — sampling the mesh, never the panel
material. That is also why `.clear` glass is legible here at all.

**Motion degrades from one file.** `Design/Motion.swift` resolves every curve in
the app from `accessibilityReduceMotion` / `accessibilityReduceTransparency`,
so views ask for `motion.morph` and the accessibility story is a single change
rather than a thirty-file audit. Nothing uses `repeatForever` without tearing it
down on disappear — a permanently live display link is real idle battery cost in
a menu bar app.

### Not in v1

App and website blocking (needs a Network Extension content filter entitlement;
`FamilyControls` is iOS-only), toggling macOS Focus modes (no public API),
iCloud sync (JSON export instead), iOS/watchOS targets, and calendar
integration.

---

## Status

The landing page was built and verified in Chromium: hero demo, the morph, the
phase palette crossfade, scroll reveals, light/dark, reduced motion, and no
console errors or external requests.

**The Swift app has not been compiled.** It was written on Linux, where there is
no SwiftUI or AppKit to typecheck against, so the first build is yours — expect
to fix a few things. The riskiest area is `MenuBar/`: prove `MenuBarExtra` +
`ImageRenderer` + the 1 Hz ticker behave on real hardware before doing any
design work on top of them. If `MenuBarExtra` turns out to be too restrictive,
the documented fallback is `NSStatusItem` + `NSPopover` — note that a custom
floating `NSPanel` degrades glass to plain blur when the app loses focus, which
is why the panel is not one.
