# Security & Privacy

charl is a local-first menu-bar utility. This document describes exactly what it stores,
what it never stores, and the only network traffic it can generate.

## Data stored locally

Everything lives in `~/Library/Application Support/charl`:

| File / dir | Content |
|---|---|
| `settings.json` | preferences (hotkeys, palette, panel layout, toggles) |
| `clipboard/` | clipboard history (text / links / image thumbnails + files) |
| `holidays.json` | your optional holiday overrides |
| `remote-cache.json` | cached weather + statutory-holiday lookups |

Screenshots you choose to save go to `~/Pictures/charl`. Deleting the data folder resets everything.

## Clipboard content that is NEVER recorded

Pasteboard items marked **sensitive, transient, concealed or auto-generated**
(`NSPasteboard.PasteboardType` conventions used by password managers etc.) are skipped entirely.
Text and image histories have capacity caps; oldest unpinned entries are evicted, pinned items kept.
Clear anytime via **Clear Unpinned** in the clipboard panel.

## Network traffic (optional, outbound-only)

No telemetry, no accounts, no analytics, no inbound connections. The only possible requests are
read-only public-API GETs, each disableable in **Settings → Calendar**:

| Purpose | Endpoint | Toggle |
|---|---|---|
| infer approximate city from IP | `ipwho.is` (fallback `ipapi.co`) | Show Weather |
| current weather + daily high/low | `wttr.in` (fallback `open-meteo.com`) | Show Weather |
| statutory holidays & work-swap | `holiday-cn` dataset (jsDelivr / GitHub raw mirror of `gov.cn` notices) | Auto-Update Holidays |

- No API keys. No personal data uploaded. Your IP is used **only** to infer a city.
- Responses cached in `remote-cache.json` (weather 30 min, holidays 1 day).
- Offline / failure falls back to built-in 2026/2027 holiday data plus your `holidays.json`;
  the weather row simply hides.

## Permissions

Screen Recording (screenshot), Accessibility (optional auto-paste), Calendar (optional events).
All are requested through the standard macOS prompts and can be revoked in System Settings.

## Reporting a vulnerability

Please **do not** open a public issue for security problems.
Use GitHub's private vulnerability reporting ("Report a vulnerability" on the Security tab),
or email the maintainer listed in the repository profile. Include reproduction steps and impact.
We aim to acknowledge within 72 hours.

## Supported versions

| Version | Supported |
|---|---|
| 0.3.x | ✅ |
| < 0.3 | ❌ |