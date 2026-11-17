// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import Carbon.HIToolbox
import Foundation
import VoltaLanguageCore

/// Optional tools that ship inside Volta. They stay off and out of sight until the user installs them
/// in Settings → Extras, and disappear again when uninstalled. Nothing is downloaded.
enum ExtraID: String, Codable, CaseIterable, Identifiable {
    case stayAwake

    var id: Self { self }

    func title(language: AppLanguage) -> String {
        switch self {
        case .stayAwake: language.localized(german: "Wach bleiben", english: "Stay Awake")
        }
    }

    func summary(language: AppLanguage) -> String {
        switch self {
        case .stayAwake:
            language.localized(
                german: "Hält deinen Mac wach, auch wenn du länger keine Maus und Tastatur berührst. Auf Wunsch bleibt auch der Bildschirm an oder der Mac läuft zugeklappt weiter.",
                english: "Keeps your Mac awake even when you leave the mouse and keyboard alone for a long time. If you like, the display stays on too, or the Mac keeps running with the lid closed.")
        }
    }

    var symbol: String {
        switch self {
        case .stayAwake: "cup.and.heat.waves.fill"
        }
    }
}

/// Options of the Stay Awake extra. Whether it is switched on is not stored: every launch starts with
/// the Mac allowed to sleep, so a forgotten switch cannot keep it awake for days.
struct AwakePrefs: Codable, Equatable {
    /// Also keep the display from dimming and turning off.
    var keepDisplayOn = false
    /// Keep running with the lid closed (needs administrator approval each time it starts).
    var lidClosed = false
    var shortcut = KeyCombo(keyCode: UInt32(kVK_ANSI_W), carbonFlags: UInt32(controlKey | optionKey), label: "⌃⌥W")
    var shortcutOn = true
    var displayShortcut = KeyCombo(keyCode: UInt32(kVK_ANSI_D), carbonFlags: UInt32(controlKey | optionKey), label: "⌃⌥D")
    var displayShortcutOn = true
}

struct ExtrasConfig: Codable, Equatable {
    var installed: [ExtraID] = []
    var awake = AwakePrefs()

    func has(_ extra: ExtraID) -> Bool { installed.contains(extra) }

    mutating func install(_ extra: ExtraID) {
        if !has(extra) { installed.append(extra) }
    }

    mutating func uninstall(_ extra: ExtraID) {
        installed.removeAll { $0 == extra }
    }
}

/// Two global shortcuts with the same keys cannot both be registered.
enum ShortcutClash {
    /// True if one of Volta's other active shortcuts already uses these keys.
    static func exists(_ combo: KeyCombo, among others: [KeyCombo]) -> Bool {
        others.contains { $0.keyCode == combo.keyCode && $0.carbonFlags == combo.carbonFlags }
    }
}
