# Contributing to charl

Thanks for considering a contribution! charl is a small native macOS app; keeping it small,
native and private is the goal.

## Setup

```bash
git clone https://github.com/char518/charl.git
cd charl
swift build
swift run CharlCoreTests
swift run CharlIntegrationTests
```

Requires macOS 14+ and a Swift 5.9 / Xcode toolchain. No third-party dependencies.

## Architecture rules

- **`CharlCore`** is pure Swift models — no AppKit/SwiftUI, fully unit-testable.
- **`CharlPlatform`** declares service protocols; **`CharlMac`** implements them for macOS.
  `CharlUI` depends only on `CharlPlatform`, never on `CharlMac`. Keep it that way so a
  future Windows port can swap the Mac layer.
- **Rendering:** always render at the window's native `backingScaleFactor`. Do not supersample;
  it breaks cross-display and repeat-open clarity.
- **Motion:** event-driven only. Timers must settle and stop when idle (zero idle CPU).
- **Privacy:** never record sensitive/transient/concealed pasteboard content; never add telemetry;
  any new network call must be outbound-only, optional, and documented in `SECURITY.md`.
- **No secrets** in code, docs, or config defaults.
- **Copy:** every user-visible string goes through `loc("中文", "English")` (CharlCore `Lang.swift`);
  Chinese is the base text, English the counterpart. Comments, log messages and strings compared in
  logic stay Chinese — they are data, not copy. Proper nouns (solar terms, festivals, statutory
  holidays) translate through `AlmanacNames`, which also has compact forms for the calendar grid;
  unknown names fall back to the original text.

## Before opening a PR

- [ ] `swift build` clean (no new warnings).
- [ ] `swift run CharlCoreTests` and `swift run CharlIntegrationTests` pass.
- [ ] UI changes verified by actually running the app (`bash Scripts/build-app.sh && open dist/charl.app`),
      in both light and dark mode, on Retina and a non-Retina display if possible.
- [ ] New user-facing strings provided in both English and 简体中文 where applicable.
- [ ] Privacy/network impact reflected in `README.md`, `README.zh-CN.md` and `SECURITY.md`.

## Commit / PR style

- Small, focused commits; imperative subject ("fix clipboard scroll routing", not "fixed stuff").
- One logical change per PR; describe the user-visible effect and how you verified it.
- Screenshots/GIFs welcome for UI changes (sanitize any personal clipboard content first).

## Reporting bugs

Use the issue templates. Include macOS version, display setup (Retina / external), and steps.
For security issues see [SECURITY.md](SECURITY.md) — do not file them publicly.