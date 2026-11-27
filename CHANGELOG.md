# Changelog

All notable changes to charl are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/); versions follow [SemVer](https://semver.org/).

## [0.3.1]

### Changed
- Screenshot: a single click now picks the window under the pointer (previously double-click);
  clicking empty space clears the selection. With a region selected, double-clicking anywhere —
  inside or outside — copies and finishes it, keeping the region and its annotations.
- Screenshot: clicking another window while a selection exists highlights it first and switches
  after the double-click interval, so a double-click copy never flickers.
- Clipboard: card actions (preview / copy / delete / pin) are always visible, dimmed until hovered;
  character count / image size sit next to them. Cards use a uniform width per density so repeated
  deletes at a stationary pointer stay aligned.

### Fixed
- Clipboard: deleting a card no longer breaks clicking the next card under a stationary pointer.
  List changes use differential batch updates instead of rebuilding every card (rebuilt SwiftUI hosts
  could stay unrendered and swallow clicks); hover is derived from the pointer position on move,
  layout and scroll.
- Screenshot: double-clicking inside the selection no longer replaces it with the window under the
  pointer.
- Screenshot: the annotation toolbar hides when the selection is cleared.

## [0.3.0]

### Added
- **i18n:** full Chinese + English UI. Language follows the system preference by default and can be
  overridden in Settings → General; menu, panels, hotkey recorder, toasts and the system permission
  prompts (Calendar / Screen Recording) are all localized. Lunar dates, solar terms, festivals and
  statutory holidays have English names, with compact forms for the calendar grid.
- **Calendar:** live local weather (IP-inferred city) and real-time statutory-holiday updates via
  optional outbound-only public APIs, with offline fallback to built-in 2026/2027 data.
- **Calendar:** 10 accent presets + custom color; three background modes (native glass / clear / solid);
  adjustable font size with auto-sizing window; lunar / festival / solar-term / Off·Work badges; day detail
  with countdown and system events.
- **Clipboard:** gravity-rope visual with event-driven motion; full-width auto + drag-resize;
  height & rope-opacity settings; capacity + eviction (pinned kept); search & type filters;
  panel follows the mouse's display.
- **Screenshot:** instant freeze; region / window selection; arrow / rect / ellipse / pen / mosaic /
  inline-text annotation; undo; native-resolution output; pin-to-screen; auto-save.
- **Pin:** float clipboard images on screen.
- Editable global hotkeys with recording + saved feedback; dark mode; universal (arm64 + x86_64) binary.
- Privacy toggles (Show Weather / Auto-Update Holidays); local caching; `SECURITY.md` privacy & network model.

### Fixed
- Cross-display and repeat-open text clarity (native backing-scale rendering, no supersampling).
- Clipboard wheel-scroll routing: wheel over the panel (including inter-card gaps) scrolls the
  clipboard, never the window behind (activating panel + hit-test/scroll consumption).
- Calendar stays open during screenshot capture; centered anchoring under the menu-bar icon.
- Idle CPU reduced to zero (event-driven motion, offloaded persistence, icon/negative caches).

## [0.2.0] and earlier

Internal development builds; not published.