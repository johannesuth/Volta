// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import AppKit
import SwiftUI
import VoltaLanguageCore

// MARK: - Settings → Extras

struct InstallJob: Equatable {
    let extra: ExtraID
    let installing: Bool
    var done = false
}

/// The catalog of extras: each with a short description and an Install or Uninstall button.
struct ExtrasPrefs: View {
    @Bindable private var store = ConfigStore.shared
    @State private var job: InstallJob?

    var body: some View {
        Form {
            Section {
                ForEach(ExtraID.allCases) { row($0) }
            } header: {
                Text(Copy.text("Zusatzfunktionen", "Add-ons"))
            } footer: {
                Text(Copy.text("Extras sind in Volta enthalten und bleiben aus, bis du sie installierst. Dabei wird nichts aus dem Internet geladen. Weitere Extras kommen mit neuen Versionen dazu.",
                               "Extras come with Volta and stay off until you install them. Nothing is downloaded. More extras arrive with new versions."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .formStyle(.grouped)
        .overlay {
            if let job {
                InstallProgress(job: job, language: store.c.language)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }
        }
        .animation(.easeOut(duration: 0.22), value: job)
    }

    private func row(_ extra: ExtraID) -> some View {
        let installed = store.c.extras.has(extra)
        let language = store.c.language
        return HStack(alignment: .top, spacing: 12) {
            IconBadge(symbol: extra.symbol, hue: extra.hue, size: 38)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(extra.title(language: language)).font(.system(size: 13, weight: .semibold))
                    if installed {
                        Text(Copy.text("Installiert", "Installed"))
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .foregroundStyle(Hue.good)
                            .background(Hue.good.opacity(0.15), in: Capsule())
                    }
                }
                Text(extra.summary(language: language))
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    if installed {
                        Button(Copy.text("Einstellungen …", "Settings…")) { ExtraSettingsWindow.shared.show(extra) }
                            .buttonStyle(.borderedProminent)
                        Button(Copy.text("Deinstallieren", "Uninstall")) { run(extra, installing: false) }
                    } else {
                        Button { run(extra, installing: true) } label: {
                            Label(Copy.text("Installieren", "Install"), systemImage: "arrow.down.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.top, 2)
                .disabled(job != nil)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    /// A short, visible step: progress ring, then a check mark, then the overlay closes by itself.
    private func run(_ extra: ExtraID, installing: Bool) {
        job = InstallJob(extra: extra, installing: installing)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(installing ? 1.4 : 1.0))
            if installing {
                store.c.extras.install(extra)
            } else {
                if extra == .stayAwake { AwakeKeeper.shared.shutdown() }
                ExtraSettingsWindow.shared.close(extra)
                store.c.extras.uninstall(extra)
            }
            withAnimation(.spring(duration: 0.35)) { job?.done = true }
            try? await Task.sleep(for: .seconds(0.8))
            job = nil
        }
    }
}

private struct InstallProgress: View {
    let job: InstallJob
    let language: AppLanguage

    private var title: String {
        switch (job.installing, job.done) {
        case (true, false): language.localized(german: "Wird installiert …", english: "Installing…")
        case (true, true): language.localized(german: "Installiert", english: "Installed")
        case (false, false): language.localized(german: "Wird deinstalliert …", english: "Uninstalling…")
        case (false, true): language.localized(german: "Deinstalliert", english: "Uninstalled")
        }
    }

    var body: some View {
        ZStack {
            Rectangle().fill(.black.opacity(0.12)).ignoresSafeArea()
            VStack(spacing: 12) {
                TimelineView(.animation(paused: job.done)) { context in
                    let turn = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 0.9) / 0.9
                    ZStack {
                        Circle().stroke(job.extra.hue.opacity(0.18), lineWidth: 4)
                        Circle()
                            .trim(from: 0, to: job.done ? 1 : 0.3)
                            .stroke(job.extra.hue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(job.done ? -90 : turn * 360 - 90))
                        if job.done {
                            Image(systemName: job.installing ? "checkmark" : "trash")
                                .font(.system(size: 21, weight: .bold))
                                .foregroundStyle(job.extra.hue)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            IconBadge(symbol: job.extra.symbol, hue: job.extra.hue, size: 32)
                        }
                    }
                }
                .frame(width: 62, height: 62)
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(job.extra.title(language: language)).font(.callout).foregroundStyle(.secondary)
            }
            .frame(width: 220)
            .padding(.vertical, 22)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.primary.opacity(0.08)))
            .shadow(color: .black.opacity(0.18), radius: 22, y: 8)
        }
    }
}

// MARK: - The small settings window of one extra

@MainActor
final class ExtraSettingsWindow: NSObject, NSWindowDelegate {
    static let shared = ExtraSettingsWindow()
    private var windows: [ExtraID: NSWindow] = [:]

    func show(_ extra: ExtraID) {
        let window = windows[extra] ?? make(extra)
        windows[extra] = window
        window.title = Copy.text("\(extra.title(language: .german)) – Einstellungen", "\(extra.title(language: .english)) Settings")
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func close(_ extra: ExtraID) {
        windows[extra]?.close()
    }

    private func make(_ extra: ExtraID) -> NSWindow {
        let root: AnyView = switch extra {
        case .stayAwake: AnyView(StayAwakeSettings())
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: root))
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }

    /// Closed windows are released completely, like the main Settings window.
    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow,
              let extra = windows.first(where: { $0.value === closing })?.key else { return }
        DispatchQueue.main.async { MainActor.assumeIsolated {
            closing.contentViewController = nil
            self.windows[extra] = nil
        } }
    }
}

struct StayAwakeSettings: View {
    @Bindable private var store = ConfigStore.shared
    private let keeper = AwakeKeeper.shared

    private var status: String {
        guard keeper.active else {
            return Copy.text("Aus – dein Mac schläft wie gewohnt.", "Off – your Mac sleeps as usual.")
        }
        return AwakeStatus.text(since: keeper.since, prefs: store.c.extras.awake, language: store.c.language)
    }

    /// Volta's other shortcuts that are switched on, for the clash hint.
    private func others(than combo: KeyPath<AwakePrefs, KeyCombo>) -> [KeyCombo] {
        let prefs = store.c.extras.awake
        var list: [KeyCombo] = []
        if store.c.shortcutOn { list.append(store.c.shortcut) }
        if combo != \AwakePrefs.shortcut && prefs.shortcutOn { list.append(prefs.shortcut) }
        if combo != \AwakePrefs.displayShortcut && prefs.displayShortcutOn { list.append(prefs.displayShortcut) }
        return list
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                IconBadge(symbol: ExtraID.stayAwake.symbol, hue: ExtraID.stayAwake.hue, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ExtraID.stayAwake.title(language: store.c.language)).font(.system(size: 17, weight: .semibold))
                    Text(status).font(.callout).foregroundStyle(keeper.active ? ExtraID.stayAwake.hue : .secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 38)
            .padding(.bottom, 2)

            Form {
                Section {
                    Toggle(isOn: Binding(get: { keeper.active }, set: { keeper.set($0) })) {
                        SettingLabel(title: Copy.text("Mac wach halten", "Keep Mac awake"),
                                     detail: Copy.text("Kein Ruhezustand, solange das an ist.", "No sleep while this is on."),
                                     symbol: "cup.and.heat.waves.fill")
                    }
                    Toggle(isOn: Binding(get: { store.c.extras.awake.keepDisplayOn }, set: { on in
                        store.c.extras.awake.keepDisplayOn = on
                        if on { keeper.set(true) }
                    })) {
                        SettingLabel(title: Copy.text("Bildschirm anlassen", "Keep the display on"),
                                     detail: Copy.text("Der Bildschirm wird nicht dunkel.", "The display does not dim or turn off."),
                                     symbol: "display")
                    }
                    Toggle(isOn: Binding(get: { store.c.extras.awake.lidClosed }, set: { on in
                        store.c.extras.awake.lidClosed = on
                        if on { keeper.set(true) }
                    })) {
                        SettingLabel(title: Copy.text("Auch zugeklappt wach bleiben", "Stay awake with the lid closed"),
                                     detail: Copy.text("Fragt beim Einschalten nach deinem Administratorpasswort. Endet von selbst, wenn du es ausschaltest, Volta beendest oder der Akku unter 10 % fällt.",
                                                       "Asks for your administrator password when it starts. Ends by itself when you switch it off, quit Volta or the battery drops below 10%."),
                                     symbol: "laptopcomputer")
                    }
                    .disabled(keeper.lidPending)
                    if keeper.lidPending {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(Copy.text("Warte auf deine Freigabe …", "Waiting for your approval…"))
                                .font(.callout).foregroundStyle(.secondary)
                        }
                    }
                    if let note = keeper.lidNote {
                        Label(note, systemImage: "exclamationmark.circle").font(.callout).foregroundStyle(Hue.warn)
                    }
                }

                Section(Copy.text("Tastenkürzel", "Keyboard shortcuts")) {
                    Toggle(isOn: $store.c.extras.awake.shortcutOn) {
                        SettingLabel(title: Copy.text("Wach bleiben ein/aus", "Stay Awake on/off"),
                                     detail: Copy.text("Aus jeder App.", "From any app."), symbol: "command")
                    }
                    if store.c.extras.awake.shortcutOn {
                        shortcutRow(\.shortcut)
                    }
                    Toggle(isOn: $store.c.extras.awake.displayShortcutOn) {
                        SettingLabel(title: Copy.text("Bildschirm anlassen ein/aus", "Keep display on, on/off"),
                                     detail: Copy.text("Schaltet Wach bleiben bei Bedarf mit ein.", "Turns Stay Awake on if needed."),
                                     symbol: "display")
                    }
                    if store.c.extras.awake.displayShortcutOn {
                        shortcutRow(\.displayShortcut)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
        }
        .frame(width: 470, height: 588)
        .environment(\.locale, Locale(identifier: store.c.language.localeIdentifier))
    }

    @ViewBuilder
    private func shortcutRow(_ path: WritableKeyPath<AwakePrefs, KeyCombo>) -> some View {
        LabeledContent(Copy.text("Kombination", "Shortcut")) {
            ShortcutRecorder(combo: Binding(get: { store.c.extras.awake[keyPath: path] },
                                            set: { store.c.extras.awake[keyPath: path] = $0 }))
        }
        if ShortcutClash.exists(store.c.extras.awake[keyPath: path], among: others(than: path)) {
            Label(Copy.text("Diese Kombination nutzt Volta schon für etwas anderes.", "Volta already uses this combination for something else."),
                  systemImage: "exclamationmark.triangle")
                .font(.callout).foregroundStyle(Hue.warn)
        }
    }
}

/// "On since 14:02 · display on" for the settings window, the dashboard card and the shortcut toast.
enum AwakeStatus {
    static func since(_ since: Date?, language: AppLanguage) -> String {
        guard let since else { return language.localized(german: "An", english: "On") }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.setLocalizedDateFormatFromTemplate(language == .german ? "HH:mm" : "jmm")
        let time = formatter.string(from: since).replacingOccurrences(of: "\u{202F}", with: " ")
        return language.localized(german: "An seit \(time) Uhr", english: "On since \(time)")
    }

    /// Second line of the shortcut confirmation.
    static func toastDetail(active: Bool, prefs: AwakePrefs, language: AppLanguage) -> String {
        guard active else { return language.localized(german: "Dein Mac schläft wieder wie gewohnt.", english: "Your Mac sleeps as usual again.") }
        var options: [String] = []
        if prefs.keepDisplayOn { options.append(language.localized(german: "Bildschirm bleibt an", english: "display stays on")) }
        if prefs.lidClosed { options.append(language.localized(german: "auch zugeklappt", english: "also with the lid closed")) }
        guard !options.isEmpty else { return language.localized(german: "Dein Mac schläft nicht ein.", english: "Your Mac will not sleep.") }
        let joined = options.joined(separator: ", ")
        return joined.prefix(1).uppercased() + joined.dropFirst() + "."
    }

    static func text(since: Date?, prefs: AwakePrefs, language: AppLanguage) -> String {
        var parts = [Self.since(since, language: language)]
        if prefs.keepDisplayOn { parts.append(language.localized(german: "Bildschirm an", english: "display on")) }
        if prefs.lidClosed { parts.append(language.localized(german: "zugeklappt", english: "lid closed")) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Toast

/// A short confirmation near the top of the screen when a shortcut switches something, like the
/// macOS volume overlay. It ignores the mouse and fades out by itself.
@MainActor
final class Toast {
    static let shared = Toast()
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?

    func show(symbol: String, hue: Color, title: String, detail: String?) {
        hideWork?.cancel()
        let host = NSHostingView(rootView: ToastView(symbol: symbol, hue: hue, title: title, detail: detail))
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        let panel = self.panel ?? {
            let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false
            p.level = .statusBar
            p.ignoresMouseEvents = true
            p.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
            p.isReleasedWhenClosed = false
            return p
        }()
        self.panel = panel
        panel.contentView = host
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            panel.setFrame(NSRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height - 14,
                                  width: size.width, height: size.height), display: true)
        }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.15; panel.animator().alphaValue = 1 }
        let work = DispatchWorkItem { [weak self] in
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.3; panel.animator().alphaValue = 0 }) {
                MainActor.assumeIsolated {
                    guard self?.hideWork?.isCancelled == false else { return }
                    panel.orderOut(nil)
                    panel.contentView = nil
                }
            }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }
}

private struct ToastView: View {
    let symbol: String
    let hue: Color
    let title: String
    let detail: String?

    var body: some View {
        HStack(spacing: 10) {
            IconBadge(symbol: symbol, hue: hue, size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .semibold))
                if let detail { Text(detail).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary) }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassPlate(radius: 16)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.primary.opacity(0.08), lineWidth: 0.5))
        .padding(12)
        .fixedSize()
    }
}
