// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import AppKit
import SwiftUI
import UserNotifications
import VoltaLanguageCore

@main
struct VoltaMain: App {
    @NSApplicationDelegateAdaptor(Conductor.self) private var conductor
    var body: some Scene { Settings { EmptyView() } }
}

/// Wires the services together and owns the long-lived UI objects.
@MainActor
final class Conductor: NSObject, NSApplicationDelegate {
    private var presence: MenuBarPresence?
    private var shortcut: GlobalShortcut?
    private var activeCombo: KeyCombo?
    private var awakeShortcut: GlobalShortcut?
    private var awakeCombo: KeyCombo?
    private var displayShortcut: GlobalShortcut?
    private var displayCombo: KeyCombo?
    private var earlyURLs: [URL] = []

    func applicationDidFinishLaunching(_ note: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("Volta menu bar app")
        _ = Journal.shared            // starts listening for power ticks
        _ = Telemetry.shared
        _ = GadgetHub.shared
        _ = AwakeKeeper.shared
        UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
        Sentinel.shared.arm()

        LoginItem.migrateLegacyAgent()
        syncAppearance()
        syncShortcut()
        syncExtraShortcuts()

        if AppLanguage.shouldPresentOnboarding(languageChosen: ConfigStore.shared.c.languageChosen) {
            // First launch: language and permissions come first; the menu-bar item appears afterwards.
            OnboardingWindow.shared.show { [weak self] in
                self?.startMenuBar()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    MainActor.assumeIsolated { self?.presence?.open() }
                }
            }
        } else {
            startMenuBar()
        }
    }

    private func startMenuBar() {
        guard presence == nil else { return }
        let presence = MenuBarPresence()
        presence.showPreferences = { PreferencesWindow.shared.show() }
        self.presence = presence
        if !earlyURLs.isEmpty {
            let queued = earlyURLs
            earlyURLs = []
            // The status item needs a moment to get its place in the menu bar.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                MainActor.assumeIsolated { self?.application(NSApp, open: queued) }
            }
        }
    }

    /// Applies Automatic / Light / Dark to every Volta window, immediately.
    private func syncAppearance() {
        let look = withObservationTracking {
            ConfigStore.shared.c.look
        } onChange: { [weak self] in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.syncAppearance() } }
        }
        NSApp.appearance = look.appearance
    }

    /// Re-registers the global shortcut whenever it is changed in the preferences.
    private func syncShortcut() {
        let (on, combo) = withObservationTracking {
            (ConfigStore.shared.c.shortcutOn, ConfigStore.shared.c.shortcut)
        } onChange: { [weak self] in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.syncShortcut() } }
        }
        guard on else { shortcut = nil; activeCombo = nil; return }
        guard combo != activeCombo else { return }
        shortcut = nil
        shortcut = GlobalShortcut(combo) { [weak self] in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.presence?.toggle() } }
        }
        activeCombo = combo
    }

    /// The Stay Awake shortcuts exist only while the extra is installed and each shortcut is switched on.
    private func syncExtraShortcuts() {
        let (installed, prefs) = withObservationTracking {
            (ConfigStore.shared.c.extras.has(.stayAwake), ConfigStore.shared.c.extras.awake)
        } onChange: { [weak self] in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.syncExtraShortcuts() } }
        }
        let main = installed && prefs.shortcutOn ? prefs.shortcut : nil
        if main != awakeCombo {
            awakeShortcut = nil
            awakeShortcut = main.flatMap { GlobalShortcut($0) {
                DispatchQueue.main.async { MainActor.assumeIsolated { Conductor.awakeShortcutPressed() } }
            } }
            awakeCombo = main
        }
        let display = installed && prefs.displayShortcutOn ? prefs.displayShortcut : nil
        if display != displayCombo {
            displayShortcut = nil
            displayShortcut = display.flatMap { GlobalShortcut($0) {
                DispatchQueue.main.async { MainActor.assumeIsolated { Conductor.displayShortcutPressed() } }
            } }
            displayCombo = display
        }
    }

    private static func awakeShortcutPressed() {
        let keeper = AwakeKeeper.shared
        keeper.toggle()
        let language = ConfigStore.shared.c.language
        let extra = ExtraID.stayAwake
        Toast.shared.show(
            symbol: extra.symbol, hue: extra.hue,
            title: "\(extra.title(language: language)): " + language.localized(german: keeper.active ? "an" : "aus", english: keeper.active ? "on" : "off"),
            detail: AwakeStatus.toastDetail(active: keeper.active, prefs: ConfigStore.shared.c.extras.awake, language: language))
    }

    private static func displayShortcutPressed() {
        let keeper = AwakeKeeper.shared
        keeper.toggleDisplay()
        let language = ConfigStore.shared.c.language
        let on = ConfigStore.shared.c.extras.awake.keepDisplayOn
        Toast.shared.show(
            symbol: "display", hue: ExtraID.stayAwake.hue,
            title: language.localized(german: on ? "Bildschirm bleibt an" : "Bildschirm darf aus", english: on ? "Display stays on" : "Display may turn off"),
            detail: keeper.active ? language.localized(german: "Wach bleiben ist an.", english: "Stay Awake is on.") : nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Lets the Mac sleep again; a running closed-lid guard also notices that Volta is gone.
        AwakeKeeper.shared.shutdown()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if let presence { presence.open() } else { OnboardingWindow.shared.bringToFront() }
        return false
    }

    /// volta://open · volta://close · volta://preferences · volta://demo?level=8
    func application(_ application: NSApplication, open urls: [URL]) {
        guard presence != nil else { earlyURLs += urls; return }
        for url in urls where url.scheme == "volta" {
            guard let query = URLQueryParameters.parse(url) else { continue }
            switch url.host() {
            case "open": presence?.open()
            case "close": presence?.close()
            case "preferences": PreferencesWindow.shared.show()
            case "demo":
                let level = Int(query["level"] ?? "") ?? 8
                let rule = Trigger(direction: query["up"] != nil ? .up : .down, level: level, presentation: .both, tone: "Funk")
                var s = Telemetry.shared.now
                s.minutesToEmpty = s.minutesToEmpty ?? 35
                Sentinel.shared.stage(rule, level: level, snapshot: s, preview: true)
            default: break
            }
        }
    }
}
