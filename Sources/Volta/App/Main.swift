import AppKit
import SwiftUI
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
    private var earlyURLs: [URL] = []

    func applicationDidFinishLaunching(_ note: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("Volta menu bar app")
        _ = Journal.shared            // starts listening for power ticks
        _ = Telemetry.shared
        _ = GadgetHub.shared
        Sentinel.shared.arm()

        LoginItem.migrateLegacyAgent()
        syncAppearance()
        syncShortcut()

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
