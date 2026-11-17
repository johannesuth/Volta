# Changelog

All notable changes to Volta are recorded here. Dates use ISO 8601.

## [2.2.2] — 2026-11-17

### Changed
- The number in the menu-bar battery is about 13 % larger (13 pt, “100” at 11.5 pt) so it is easier to read from a distance. The battery keeps its compact 30 × 14 pt size.

### Verification
- `swift test`: 57 tests passed; the rendering test now requires digits at least 8.5 pt tall.
- Universal app (`arm64`, `x86_64`), ad-hoc signed. The installer is unsigned and nothing is notarized yet.

## [2.2.1] — 2026-11-17

### Changed
- New first-run setup in the same style as Settings, in three short steps: welcome and language, permissions, and a “you're all set” screen that shows where Volta sits in the menu bar. The welcome sound and the feature tour were removed.
- The setup asks for both permissions Volta uses before the app starts: **Open at login** and **Notifications**. Each row shows its state (allowed, needs confirmation in System Settings, declined) and links to the right System Settings page. Volta's menu-bar item appears only after setup is finished.

### Fixed
- The level number in the colored menu-bar battery is one dark color again. Before, a digit that crossed the edge of the fill turned half white. The empty part of the battery is now light gray, like the macOS battery, so the dark number stays readable on both parts in light and dark mode.

### Verification
- `swift test`: 57 tests passed, including new tests for the uniform number color, number-to-background contrast and the permission states.
- Checked live with a separate test profile: the setup window appeared before any menu-bar item, macOS showed its notification prompt as “Mitteilungen von „Volta“”, and finishing setup added the menu-bar item and opened the dashboard.
- Universal app (`arm64`, `x86_64`), ad-hoc signed. The installer is unsigned and nothing is notarized yet.

## [2.2.0] — 2026-11-17

### Added
- Menu-bar colors by charge level, the new default: light green above 50 %, light yellow from 21 to 50 %, light red at 20 % or less. The color choices are now **By charge level**, **Accent color** and **Monochrome**. Older color settings migrate automatically.
- Settings → Menu Bar shows a live preview of the icon on a dark and a light menu bar.
- The time-to-full and time-to-empty readout adds the clock time (“bis ca. 17:40 Uhr” / “until about 5:40 PM”).

### Changed
- The menu-bar battery is about 7 % smaller (30 × 14 pt body, 11.5 pt number) so it sits better next to the clock. The number is drawn dark on the colored fill and white on the empty part of the battery, so it stays readable from a distance in both light and dark mode.
- App energy use shows each app's share of the energy used by all apps in percent (“31 %”) instead of milliwatts. The exact wattage appears as a tooltip.
- Default dashboard: battery health and app energy use are open, history is collapsed, power flow and accessories are off. Untouched earlier defaults move to the new default; custom choices are kept.
- Settings are simpler. Alerts are reduced to “battery low” and “charge target reached”, with one shared display style, sound and quiet-hours switch. The Accessories tab shows each device with a level bar and a short menu. Options without a clear use were removed: sampling intervals, watt precision, color intensity, panel background, volume and accessory order.
- Unused localization entries were removed.

### Fixed
- **Open at login** now uses macOS's own login item API. Volta appears as “Volta” with its icon in System Settings. The old launch agent, which macOS listed as “open”, is removed automatically.
- **Appearance** (Automatic, Light, Dark) now applies to all Volta windows immediately.
- **Keep open** now keeps the dashboard visible when you click into another app.

### Verification
- `swift test`: 53 tests passed, including tests for login-item migration, the pinned panel window, the appearance options, the alert plan, the level colors, the icon size, the energy-share labels and the clock-time text.
- Checked live on macOS: `sfltool dumpbtm` lists the login item as “Volta” (enabled, allowed). The pinned dashboard stayed open after Finder and another app were activated. The light/dark switch restyled the open dashboard.
- Universal app (`arm64`, `x86_64`), ad-hoc signed. The installer is unsigned and nothing is notarized yet.

## [2.1.5] — 2026-11-17

### Changed
- Dashboard sections are now independent: several can be open at the same time. The open/closed state is saved. If the panel would not fit on screen, the section that has been open longest folds away, so the panel never scrolls.
- Default sections now cover everyday battery information: charge, battery health (opened) and history (collapsed). Power flow and app energy use are off by default and grouped under Settings → Dashboard → Advanced. Untouched 2.1.3/2.1.4 defaults move to the new default; custom choices are kept.
- Battery health now shows maximum capacity, charge cycles and temperature. mAh, voltage and current are behind the new opt-in setting **Technical battery values**.

### Fixed
- History chart time labels now follow the app language. They read “07 Uhr” in German instead of “07 Uhr Uhr”.

### Verification
- `swift test`: 35 tests passed, including the new section, default-migration and chart-label tests.
- Universal app (`arm64`, `x86_64`), ad-hoc signed; the installer is unsigned and nothing is notarized yet.

## [2.1.4] — 2026-11-17

### Changed
- Rebuilt the menu-bar icon renderer. The icon is now vector-drawn by AppKit at the display's own pixel density on whole-point bounds. Previously it was a pre-rendered bitmap with a fractional width (31.8 pt) that macOS resampled, which softened the number.
- Enlarged the battery to 32 × 15 pt with a 12 pt bold level figure. Colored icons use a brighter fill with near-black digits; the monochrome icon cuts the digits out of the battery body.
- Power flow (opened) and History (collapsed) were enabled by default (superseded in 2.1.5).
- Added GitHub project files: macOS CI workflow, issue templates, contribution notes, a security policy and release notes.

### Verification
- `swift test`: 30 tests passed, including pixel-level rendering checks for digit height, contrast and the monochrome cut-out.
- Live menu-bar comparison on a Retina display: the Volta battery measures 64 × 30 px (32 × 15 pt), the same size as the reference battery icon.
- Universal app (`arm64`, `x86_64`), ad-hoc signed; the installer is unsigned and nothing is notarized yet.

## [2.1.3] — 2026-11-17

### Changed
- Removed the dashboard zoom controls and resize grip; the dropdown now uses one fixed, readable size and no longer scrolls.
- Made the charge overview the only dashboard section enabled by default. Optional sections can be enabled in Settings and start collapsed; opening one collapses another.
- The history chart now loads its data only when opened. Reduced dashboard color accents to one muted selection while preserving status warnings.
- Reduced the default app list to three rows and capped it at six.

### Verification
- `swift test`: 25 tests passed.
- The local universal build is ad-hoc signed; the installer is unsigned and not notarized.

## [2.1.2] — 2026-11-17

### Added
- Added a menu-bar icon color picker with blue as the default, plus green, teal, violet, amber, rose, automatic status colours and monochrome.

### Changed
- Replaced colloquial German labels such as “Stromfresser” with neutral, clearer wording, and refined battery health, charging and power labels.

### Verification
- `swift test`: 23 tests passed.
- The local universal build remains ad-hoc signed; the installer is unsigned and notarization is still required for public distribution.

## [2.1.1] — 2026-11-16

### Changed
- Replaced observation-driven menu-bar redraws with coalesced updates from explicit data and settings events.
- Removed the 30 FPS charging shimmer and permanent loading spinners; empty data states now explain what is unavailable.
- Simplified the dashboard to a muted shared accent with softer status colours.
- Clarified German/English labels for battery, history, accessories and data-retention settings.

### Fixed
- Prevented a rapid main-thread redraw loop that could consume a full CPU core and make the app feel unstable.

### Verification
- `swift test`: 18 tests passed; the installed universal app contains `arm64` and `x86_64` slices.
- With the dashboard open, four consecutive one-second CPU samples were 4.3–5.7%; the main thread was waiting in 3,226 of 3,473 profiler samples.
- The ZIP and installer SHA-256 manifest verifies; the app remains ad-hoc signed and the package unsigned until Developer ID certificates are configured.

## [2.1.0] — 2026-11-16

### Added
- First-run language selection for German and English, with a three-step animated onboarding flow and an optional welcome sound.
- A persistent language selector in Settings → General; first-run onboarding appears until a language has been chosen.
- Complete German and English localization resources for the app interface, menu labels, settings, onboarding, bundle display names and macOS Automation permission prompt.
- A separately testable `VoltaLanguageCore` module for language detection, localized text selection, onboarding state, safe file replacement and history-import policy.
- Isolated `--profile <name>` support for QA runs, storing test settings under a separate Application Support folder.
- Universal release packaging for Apple silicon and Intel, version/build metadata, a local `.pkg`, and a per-user installer command.
- A documented Developer ID and notarization workflow, GitHub release checklist, Homebrew Cask draft, privacy guide and settings manual.

### Changed
- Bumped the app version to **2.1.0** (build **21**).
- Localized relative-time and unit formatting according to the selected app language.
- Added migration support for existing silent-alert values while keeping the stored silent identifier stable.
- Preserved existing preferences and data when building/installing; previous app bundles are kept as timestamped backups.

### Fixed
- Settings resets preserve the configured history-retention period, preventing later journal compaction from removing older entries unexpectedly.
- Custom alert-tone imports stage the copy before replacing a same-named tone; selecting the existing file is a no-op.
- Added English translations for the `Anzeige` and `Entfernen` settings labels.
- Build and notarization scripts now regenerate `dist/SHA256SUMS.txt` from the final ZIP and installer package.
- Clearing history persists a tombstone, cancels pre-clear imports and queued power samples, and leaves explicit macOS-log import available.
- Duplicate query keys in `volta://` links are rejected instead of crashing the app; failed history writes now show a localized error.
- Release scripts validate version and build-number inputs before using them in artifact paths or the app bundle plist.

### Verification
- `swift test` passes.
- `build/Volta.app` passes strict code-signature verification and contains `arm64` and `x86_64` slices.
- Local release artifacts are explicitly marked ad-hoc/unsigned until Developer ID signing and Apple notarization are configured.
