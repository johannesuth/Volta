# Changelog

All notable changes to Volta are recorded here. Dates use ISO 8601.

## [2.4.1] — 2026-11-17

### Changed
- The dashboard sections are now separate, softly rounded cards: a slightly lighter surface, a fine edge that is brighter at the top in dark mode and a soft grey line in light mode, and 7 pt between the cards (was 5). Corners are a touch rounder (15 pt). The panel grows by only 12 pt.

### Verification
- `swift test`: 88 tests passed (74 app, 14 language core). A new render test checks in dark and light mode that each card's surface and edge stand out from the gap between cards.
- Checked live in dark and light mode.

## [2.4.0] — 2026-11-17

### Added
- Fifth menu-bar style **Logo only** (“Nur Logo”): Volta's logo mark, the ring arc and bolt from the app icon, drawn as a sharp vector at system-icon size. Like the macOS icons it turns white on a dark and black on a light menu bar; the charge level appears in its tooltip. All five styles sit in one row in Settings → Menu Bar.
- With the logo selected, Settings hides the options that have no effect on it (color, hide number when full) and explains how the logo behaves.

### Verification
- `swift test`: 85 tests passed (71 app, 14 language core), including new tests for the logo's size, system tinting, its ring and bolt, and that it is never redrawn when only the level changes.
- Checked live: the five styles in one row, the logo in the preview on dark and light bars, and the logo in the real menu bar.

## [2.3.3] — 2026-11-17

### Changed
- Much lower energy and memory use. Measured on the same Mac with the same procedure (fresh start, dashboard and Settings opened once):
  - Dashboard closed: CPU 3.4–3.6 % → 0.02 %, `top` energy score 3.2–3.4 → 0.0.
  - Dashboard open: CPU 8.6–9.4 % → 4.7–5.0 %, energy score 7.7–8.6 → 4.0, memory 119 MB → 45 MB on average, own GPU time 0.22 → 0 ms/s.
  - Idle after using the dashboard: memory 56–62 MB → 34 MB (43–44 MB after Settings was also open).
- The history chart is drawn by Volta itself in one canvas instead of Swift Charts, which kept about 60 MB of GPU memory alive. It looks the same; the hover label now sits opposite the point so it never hides it.
- The menu-bar icon is replaced only when something visible changes. Before, setting the icon nudged the button's appearance, which triggered a repaint about five times per second while nothing changed.
- A closed dashboard and a closed Settings window are released completely and rebuilt on the next open.
- In the background, Volta samples the battery when macOS reports a change (level, adapter, estimate) and otherwise once a minute, instead of every 20 seconds.
- App energy is measured only while that section is open; process paths are cached and app icons stored as small bitmaps.
- Accessories are scanned every 2 minutes in the background (every 10 seconds while the section is visible), and not at all when nothing uses them.

### Verification
- `swift test`: 81 tests passed (67 app, 14 language core), including new tests for the icon signature, sampling rhythms, process-path cache, small app icons and the chart geometry.
- CPU and energy from `ps`/`top`, memory from `footprint` (sampled every second for 30 s while open), GPU time from the graphics driver's per-client statistics. The chart and its hover label were compared side by side with 2.3.2.

## [2.3.2] — 2026-11-17

### Changed
- The number in the menu-bar battery is about 10 % smaller (11.7 pt, “100” at 10.4 pt) and now matches the macOS battery number. The battery keeps its 30 × 14 pt size.
- The dashboard is more compact again: 312 instead of 336 pt wide (−7 %) and 612 instead of 713 pt tall with every section open (−14 %). Text keeps its size; the space comes from tighter spacing and a slightly flatter history chart.
- With no accessory connected, the Accessories section is one line (“Keins verbunden” / “None connected”) instead of two.

### Verification
- `swift test`: 70 tests passed (56 app, 14 language core).
- Checked live in German and English: no wrapping, truncation or clipping at the new width, and the menu-bar number next to the macOS battery.

## [2.3.1] — 2026-11-17

### Changed
- The dashboard is more compact: about 9 % shorter (713 instead of 782 pt with every section open) and 336 instead of 352 pt wide. Text is about 5 % larger at the same time.
- “Remaining” and the time now share one line, and the German label “Laufzeit bei voller Ladung” is now “Mit voller Ladung”, so it no longer wraps.
- The number in the menu-bar battery is slightly lighter: weight 640 on the system font's weight axis instead of bold (700), about 5 % less ink. Size and contrast are unchanged.
- The alert preview in Settings draws its glowing edge like the real one, with a wide soft halo, a tighter glow and a thin rim, so it no longer looks pixelated. The hard strip at the top was removed.

### Fixed
- German low-battery alerts read “Noch etwa 42 Min. Laufzeit – halte das Netzteil bereit.” instead of “… 42 Min.. Halte …”.

### Verification
- `swift test`: 70 tests passed (56 app, 14 language core), including new tests for the number weight, the compact panel and the alert text in both languages.
- Checked live in German and English: panel size, no wrapping or clipping, the preview glow, and the menu-bar number rendered before and after at 4×.

## [2.3.0] — 2026-11-17

### Added
- Disk-image installer `Volta-<version>.dmg` with a designed window: the Volta icon, an arrow and an Applications shortcut, with “Drag Volta into Applications” in English and German. Built by `Scripts/make-dmg.sh`; it replaces the ZIP, the unsigned `.pkg` and the per-user install command.
- Live alert preview in Settings → Alerts, switchable between “battery low” and “charge target reached”.
- Alert color: by charge level (default) or blue, teal, mint, indigo, amber or rose.
- License and copyright notice in Settings → About, in the app's Info.plist, on the installer window and in every source file.

### Changed
- The “Notification” alert style now always posts a real macOS notification, also while Volta is in front, and it appears in Notification Center. Before, it could look like the card.
- Alert cards stay for five seconds, then fade out. The display time is no longer a setting.
- History chart: charging phases are green and battery phases blue. Gaps in the log are bridged and colored by what must have happened (a rising level counts as charging), so charging phases no longer disappear. The range switch is a compact pill control.
- English chart labels show “5 PM” instead of an ambiguous “17”.
- Dashboard text is about 11 % larger; the panel keeps its size.
- The welcome step of the first-run setup shows three short feature chips.
- `build-app.sh --install` replaces the installed app instead of leaving `Volta.app.backup.*` copies in Applications.
- `sign-notarize.sh` signs, notarizes and staples the app and the disk image.
- License: Volta is free to use and source-available. Using and building it for yourself is allowed; copying, republishing or redistributing the code is not.

### Verification
- `swift test`: 68 tests passed (54 app, 14 language core), including new tests for alert options, the fixed five-second display time, configuration merging, chart segments and English time labels.
- Checked live: the disk image opens with the designed window and ejects cleanly; a test notification was delivered by macOS; a test card disappeared after five seconds; the setup and dashboard were checked in English and German.
- Universal app (`arm64`, `x86_64`), ad-hoc signed. The disk image is not notarized yet.

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
