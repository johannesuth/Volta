import SwiftUI
import AppKit
import VoltaLanguageCore

enum PrefTab: String, CaseIterable, Identifiable {
    case general, menubar, dashboard, alerts, gadgets, history, about
    var id: Self { self }
    var title: String {
        switch self {
        case .general: Copy.text("Allgemein", "General")
        case .menubar: Copy.text("Menüleiste", "Menu Bar")
        case .dashboard: "Dashboard"
        case .alerts: Copy.text("Warnungen", "Alerts")
        case .gadgets: Copy.text("Zubehör", "Accessories")
        case .history: Copy.text("Verlauf", "History")
        case .about: Copy.text("Info", "About")
        }
    }
    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .menubar: "menubar.rectangle"
        case .dashboard: "rectangle.grid.1x2"
        case .alerts: "bell.badge"
        case .gadgets: "headphones"
        case .history: "clock.arrow.circlepath"
        case .about: "info.circle"
        }
    }
}

struct PreferencesView: View {
    @State private var tab: PrefTab = .general
    @Bindable private var store = ConfigStore.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                ForEach(PrefTab.allCases) { t in
                    Button { tab = t } label: {
                        VStack(spacing: 4) {
                            Image(systemName: t.symbol).font(.system(size: 15, weight: .medium)).frame(height: 20)
                            Text(t.title).font(.system(size: 11, weight: .medium))
                        }
                        .frame(width: 84, height: 50)
                        .foregroundStyle(tab == t ? Hue.accent : .secondary)
                        .background(tab == t ? Hue.accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 34)
            .padding(.bottom, 8)
            Divider()
            Group {
                switch tab {
                case .general: GeneralPrefs()
                case .menubar: MenuBarPrefs()
                case .dashboard: DashboardPrefs()
                case .alerts: AlertPrefs()
                case .gadgets: GadgetPrefs()
                case .history: HistoryPrefs()
                case .about: AboutPrefs()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 640, minHeight: 600)
        .ignoresSafeArea(edges: .top)
        .environment(\.locale, Locale(identifier: store.c.language.localeIdentifier))
        .tint(Hue.accent)
    }
}

// MARK: - Shared pieces

/// A settings row label: a small icon tile, a title and an optional one-line explanation.
private struct SettingLabel: View {
    let title: String
    var detail: String? = nil
    let symbol: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Hue.accent.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// Menu-bar artwork as it would appear on a dark or light menu bar.
private struct MenuBarSample: View {
    var level: Int
    var style: GlyphStyle
    var dark: Bool
    private let store = ConfigStore.shared

    var body: some View {
        var cfg = store.c
        cfg.glyph = style
        var s = Telemetry.shared.now
        s.hasPack = true
        s.level = level
        let image = GlyphPainter.image(snapshot: s, clock: "3:10", cfg: cfg, darkBar: dark, badges: [])
        return Image(nsImage: image)
            .renderingMode(image.isTemplate ? .template : .original)
            .foregroundStyle(dark ? Color.white : Color.black)
    }
}

// MARK: - General

private struct GeneralPrefs: View {
    @Bindable private var store = ConfigStore.shared
    @State private var launchAtLogin = LoginItem.isEnabled || LoginItem.needsApproval
    @State private var needsApproval = LoginItem.needsApproval
    @State private var loginError: String?
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section(Copy.text("Sprache", "Language")) {
                Picker(selection: $store.c.language) {
                    Text(verbatim: "Deutsch").tag(AppLanguage.german)
                    Text(verbatim: "English").tag(AppLanguage.english)
                } label: {
                    SettingLabel(title: Copy.text("App-Sprache", "App language"), symbol: "globe")
                }
                .pickerStyle(.segmented)
                .onChange(of: store.c.language) { _, _ in
                    store.c.languageChosen = true
                    PreferencesWindow.shared.refreshTitle()
                }
            }

            Section(Copy.text("Start", "Startup")) {
                Toggle(isOn: Binding(get: { launchAtLogin }, set: setLaunch)) {
                    SettingLabel(title: Copy.text("Beim Anmelden starten", "Open at login"),
                                 detail: Copy.text("Volta startet automatisch, wenn du dich anmeldest.",
                                                   "Volta starts automatically when you log in."),
                                 symbol: "power")
                }
                if needsApproval {
                    LabeledContent {
                        Button(Copy.text("Anmeldeobjekte öffnen …", "Open Login Items …")) { LoginItem.openSystemSettings() }
                    } label: {
                        Text(Copy.text("macOS muss Volta in den Anmeldeobjekten noch erlauben.",
                                       "Allow Volta in macOS Login Items to finish."))
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }
                if let loginError {
                    Text(loginError).font(.callout).foregroundStyle(Hue.alarm)
                }
                Toggle(isOn: $store.c.shortcutOn) {
                    SettingLabel(title: Copy.text("Tastenkürzel", "Keyboard shortcut"),
                                 detail: Copy.text("Öffnet und schließt das Dashboard aus jeder App.",
                                                   "Opens and closes the dashboard from any app."),
                                 symbol: "command")
                }
                if store.c.shortcutOn {
                    LabeledContent(Copy.text("Kombination", "Shortcut")) { ShortcutRecorder(combo: $store.c.shortcut) }
                }
            }

            Section(Copy.text("Darstellung", "Appearance")) {
                Picker(selection: $store.c.look) {
                    ForEach(Look.allCases) { Text($0.title).tag($0) }
                } label: {
                    SettingLabel(title: Copy.text("Erscheinungsbild", "Appearance"), symbol: "circle.lefthalf.filled")
                }
                .pickerStyle(.segmented)
                LabeledContent {
                    HStack(spacing: 9) {
                        ForEach(Accent.allCases) { a in
                            Button { store.c.accent = a } label: {
                                Circle()
                                    .fill(Hue.swatch(a))
                                    .frame(width: 16, height: 16)
                                    .overlay(Circle().stroke(.primary.opacity(store.c.accent == a ? 0.85 : 0), lineWidth: 1.5).padding(-3))
                            }
                            .buttonStyle(.plain)
                            .help(a.title)
                        }
                    }
                } label: {
                    SettingLabel(title: Copy.text("Akzentfarbe", "Accent color"), symbol: "paintpalette.fill")
                }
                Picker(selection: $store.c.fahrenheit) {
                    Text("°C").tag(false)
                    Text("°F").tag(true)
                } label: {
                    SettingLabel(title: Copy.text("Temperatur", "Temperature"), symbol: "thermometer.medium")
                }
                .pickerStyle(.segmented)
            }

            Section {
                Button(Copy.text("Alle Einstellungen zurücksetzen …", "Reset all settings …"), role: .destructive) { confirmReset = true }
            } footer: {
                Text(Copy.text("Verlauf und bekanntes Zubehör bleiben erhalten.", "History and known accessories are kept."))
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(Copy.text("Alle Einstellungen zurücksetzen?", "Reset all settings?"), isPresented: $confirmReset) {
            Button(Copy.text("Zurücksetzen", "Reset"), role: .destructive) { store.restoreDefaults() }
        }
        .onAppear(perform: refreshLogin)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refreshLogin() }
    }

    private func setLaunch(_ on: Bool) {
        loginError = nil
        do {
            try LoginItem.set(on)
        } catch {
            loginError = Copy.text("Das hat nicht geklappt: \(error.localizedDescription)",
                                   "That didn't work: \(error.localizedDescription)")
        }
        refreshLogin()
    }

    private func refreshLogin() {
        needsApproval = LoginItem.needsApproval
        launchAtLogin = LoginItem.isEnabled || needsApproval
    }
}

/// Click, then press the new combination (needs at least one modifier).
private struct ShortcutRecorder: View {
    @Binding var combo: KeyCombo
    @State private var listening = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            listening ? stop() : start()
        } label: {
            Text(listening ? Copy.text("Tasten drücken …", "Press keys …") : combo.label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .frame(minWidth: 110)
        }
        .buttonStyle(.bordered)
        .tint(listening ? Hue.warn : nil)
        .help(Copy.text("Klicken und neue Tastenkombination drücken", "Click, then press a new combination"))
        .onDisappear(perform: stop)
    }

    private func start() {
        listening = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { stop(); return nil }          // Esc cancels
            if let new = GlobalShortcut.combo(from: event) { combo = new; stop(); return nil }
            return event
        }
    }

    private func stop() {
        listening = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

// MARK: - Menu bar

private struct MenuBarPrefs: View {
    @Bindable private var store = ConfigStore.shared

    private var previewLevels: [Int] {
        store.c.glyphTint == .level ? [85, 40, 15] : [max(Telemetry.shared.now.level, 1)]
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    previewBar(dark: true)
                    previewBar(dark: false)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            } header: {
                Text(Copy.text("Vorschau", "Preview"))
            }

            Section(Copy.text("Symbol", "Icon")) {
                HStack(spacing: 10) {
                    ForEach(GlyphStyle.choices) { style in
                        Button { store.c.glyph = style } label: {
                            VStack(spacing: 7) {
                                MenuBarSample(level: 72, style: style, dark: true)
                                    .frame(maxWidth: .infinity, minHeight: 32)
                                    .background(Color(white: 0.13), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                                Text(style.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
                            }
                            .padding(7)
                            .background(store.c.glyph == style ? Hue.accent.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(store.c.glyph == style ? Hue.accent : Color.secondary.opacity(0.2), lineWidth: store.c.glyph == style ? 1.5 : 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }

            Section {
                Picker(selection: $store.c.glyphTint) {
                    ForEach(GlyphTint.allCases) { Text($0.title).tag($0) }
                } label: {
                    SettingLabel(title: Copy.text("Farbe", "Color"), symbol: "paintbrush.fill")
                }
                .pickerStyle(.segmented)
            } footer: {
                Text(tintExplanation)
            }

            Section(Copy.text("Optionen", "Options")) {
                Toggle(isOn: $store.c.glyphWatts) {
                    SettingLabel(title: Copy.text("Leistung in Watt", "Power in watts"),
                                 detail: Copy.text("Zeigt den aktuellen Verbrauch neben dem Akku.", "Shows the current power draw next to the battery."),
                                 symbol: "bolt.fill")
                }
                Toggle(isOn: $store.c.glyphQuietWhenFull) {
                    SettingLabel(title: Copy.text("Zahl bei vollem Akku ausblenden", "Hide the number when full"),
                                 detail: Copy.text("Nur am Netzteil bei 100 %.", "Only on power at 100%."),
                                 symbol: "eye.slash")
                }
            }
        }
        .formStyle(.grouped)
    }

    private var tintExplanation: String {
        switch store.c.glyphTint {
        case .level: Copy.text("Grün über 50 %, Gelb bis 50 %, Rot ab 20 %.", "Green above 50%, yellow down to 21%, red at 20% or less.")
        case .accent: Copy.text("Verwendet die Akzentfarbe aus „Allgemein“.", "Uses the accent color from General.")
        case .monochrome: Copy.text("Schwarz-weiß wie das Batteriesymbol von macOS.", "Black and white, like the macOS battery icon.")
        }
    }

    private func previewBar(dark: Bool) -> some View {
        HStack(spacing: 18) {
            ForEach(previewLevels, id: \.self) { level in
                MenuBarSample(level: level, style: store.c.glyph, dark: dark)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 30)
        .background(dark ? Color(white: 0.11) : Color(white: 0.93), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Dashboard

private struct DashboardPrefs: View {
    @Bindable private var store = ConfigStore.shared

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $store.c.stickyDropdown) {
                    SettingLabel(title: Copy.text("Offen halten", "Keep open"),
                                 detail: Copy.text("Das Dashboard bleibt offen, auch wenn du in eine andere App klickst.",
                                                   "The dashboard stays open when you click into another app."),
                                 symbol: "pin.fill")
                }
            }

            Section {
                tileToggle(.vitals, detail: Copy.text("Kapazität, Ladezyklen und Temperatur", "Capacity, charge cycles and temperature"))
                tileToggle(.apps, detail: Copy.text("Welche Apps gerade am meisten Strom brauchen", "Which apps use the most power right now"))
                tileToggle(.trend, detail: Copy.text("Ladestand der letzten Stunden", "Charge level over recent hours"))
                if !store.c.hiddenTiles.contains(.trend) {
                    Picker(Copy.text("Zeitraum", "Range"), selection: $store.c.chartSpan) {
                        ForEach(ChartSpan.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                tileToggle(.gadgets, detail: Copy.text("Akkustand von AirPods, Maus, Tastatur & Co.", "Battery of AirPods, mouse, keyboard and more"))
            } header: {
                Text(Copy.text("Bereiche", "Sections"))
            } footer: {
                Text(Copy.text("Im Dashboard klappst du einen Bereich mit einem Klick auf die Überschrift auf oder zu.",
                               "In the dashboard, click a section title to expand or collapse it."))
            }

            Section(Copy.text("Für Fortgeschrittene", "Advanced")) {
                tileToggle(.balance, detail: Copy.text("Leistung von Netzteil, Akku und Mac in Watt", "Adapter, battery and Mac power in watts"))
                Toggle(isOn: $store.c.showBatteryDetails) {
                    SettingLabel(title: Copy.text("Technische Akkuwerte", "Technical battery values"),
                                 detail: Copy.text("mAh, Spannung und Strom im Akkuzustand", "mAh, voltage and current in Battery health"),
                                 symbol: "gauge.with.dots.needle.33percent")
                }
            }
        }
        .formStyle(.grouped)
    }

    private func tileToggle(_ tile: TileKind, detail: String) -> some View {
        Toggle(isOn: Binding(get: { !store.c.hiddenTiles.contains(tile) },
                             set: { store.toggleTile(tile, on: $0) })) {
            SettingLabel(title: tile.title, detail: detail, symbol: tile.icon)
        }
    }
}

// MARK: - Alerts

private struct AlertPrefs: View {
    @Bindable private var store = ConfigStore.shared
    @State private var tones = Chime.catalog()

    var body: some View {
        Form {
            Section(Copy.text("Akku", "Battery")) {
                Toggle(isOn: $store.c.alerts.lowOn) {
                    SettingLabel(title: Copy.text("Akku fast leer", "Battery low"),
                                 detail: Copy.text("Erinnert dich rechtzeitig ans Aufladen.", "Reminds you to charge in time."),
                                 symbol: "battery.25percent")
                }
                if store.c.alerts.lowOn {
                    levelPicker(Copy.text("Warnen bei", "Warn at"), selection: $store.c.alerts.lowLevel, options: AlertPlan.lowLevels)
                }
                Toggle(isOn: $store.c.alerts.fullOn) {
                    SettingLabel(title: Copy.text("Ladeziel erreicht", "Charge target reached"),
                                 detail: Copy.text("Sagt Bescheid, wenn du das Netzteil abziehen kannst.", "Tells you when you can unplug."),
                                 symbol: "bolt.fill")
                }
                if store.c.alerts.fullOn {
                    levelPicker(Copy.text("Bescheid geben bei", "Notify at"), selection: $store.c.alerts.fullLevel, options: AlertPlan.fullLevels)
                }
            }

            Section(Copy.text("So wirst du erinnert", "How you're notified")) {
                Picker(selection: $store.c.alerts.style) {
                    ForEach(AlertPlan.styles) { Text($0.title).tag($0) }
                } label: {
                    SettingLabel(title: Copy.text("Anzeige", "Display"), symbol: "rectangle.on.rectangle")
                }
                .pickerStyle(.segmented)
                .onChange(of: store.c.alerts.style) { _, style in
                    if style == .banner { Sentinel.shared.requestNotificationPermission() }
                }
                Picker(selection: $store.c.alerts.tone) {
                    ForEach(tones, id: \.self) { tone in
                        Text(tone == Chime.silent ? Copy.text("Kein Ton", "No sound") : tone).tag(tone)
                    }
                } label: {
                    SettingLabel(title: Copy.text("Ton", "Sound"), symbol: "speaker.wave.2.fill")
                }
                .onChange(of: store.c.alerts.tone) { _, tone in Chime.ring(tone, force: true) }
                Toggle(isOn: $store.c.quiet.enabled) {
                    SettingLabel(title: Copy.text("Nachts stumm", "Quiet at night"),
                                 detail: Copy.text("Zwischen 22 und 7 Uhr ohne Ton.", "No sound between 10 PM and 7 AM."),
                                 symbol: "moon.fill")
                }
                Toggle(isOn: $store.c.plugTone) {
                    SettingLabel(title: Copy.text("Ton beim Ein- und Ausstecken", "Sound when plugging in or out"),
                                 symbol: "powerplug.fill")
                }
            }

            Section {
                Button(action: preview) {
                    Label(Copy.text("Warnung testen", "Test alert"), systemImage: "play.fill")
                }
                .disabled(!store.c.alerts.lowOn && !store.c.alerts.fullOn)
            } footer: {
                Text(Copy.text("Warnungen für Zubehör stellst du im Tab „Zubehör“ ein.", "Accessory alerts are in the Accessories tab."))
            }
        }
        .formStyle(.grouped)
        .onAppear { tones = Chime.catalog() }
    }

    private func levelPicker(_ title: String, selection: Binding<Int>, options: [Int]) -> some View {
        let values = Array(Set(options + [selection.wrappedValue])).sorted()
        return Picker(title, selection: selection) {
            ForEach(values, id: \.self) { Text("\($0) %").tag($0) }
        }
        .padding(.leading, 36)
    }

    private func preview() {
        guard let rule = store.c.alerts.triggers.first else { return }
        var s = Telemetry.shared.now
        s.minutesToEmpty = s.minutesToEmpty ?? 42
        Sentinel.shared.stage(rule, level: rule.level, snapshot: s, preview: true)
    }
}

// MARK: - Accessories

private struct GadgetPrefs: View {
    @Bindable private var store = ConfigStore.shared
    @State private var scanning = false
    private let hub = GadgetHub.shared

    var body: some View {
        Form {
            Section {
                if hub.all.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "headphones")
                            .font(.system(size: 30, weight: .light))
                            .foregroundStyle(Hue.accent)
                        Text(Copy.text("Noch kein Zubehör gefunden", "No accessories found yet")).font(.headline)
                        Text(Copy.text("Verbinde AirPods, eine Maus oder Tastatur mit Akku. Volta liest den Akkustand direkt aus macOS – ohne Bluetooth-Freigabe.",
                                       "Connect AirPods, a mouse or a keyboard with a battery. Volta reads the level directly from macOS, without Bluetooth permission."))
                            .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Button(Copy.text("Bluetooth-Einstellungen öffnen", "Open Bluetooth Settings")) { Shortcuts.bluetoothPane() }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                } else {
                    ForEach(hub.all) { AccessoryRow(gadget: $0) }
                }
            } header: {
                HStack {
                    Text(Copy.text("Geräte", "Devices"))
                    Spacer()
                    Button {
                        scanning = true
                        Task { await hub.rescan(); scanning = false }
                    } label: {
                        Label(Copy.text("Aktualisieren", "Refresh"), systemImage: "arrow.clockwise")
                    }
                    .controlSize(.small)
                    .disabled(scanning)
                }
            }

            Section(Copy.text("Optionen", "Options")) {
                Toggle(isOn: Binding(get: { !store.c.hiddenTiles.contains(.gadgets) },
                                     set: { store.toggleTile(.gadgets, on: $0) })) {
                    SettingLabel(title: Copy.text("Im Dashboard zeigen", "Show in dashboard"),
                                 detail: Copy.text("Eigener Bereich mit allen verbundenen Geräten.", "A section listing all connected devices."),
                                 symbol: "rectangle.grid.1x2")
                }
                Toggle(isOn: Binding(get: { store.c.gadgetFloor > 0 }, set: { store.c.gadgetFloor = $0 ? 20 : 0 })) {
                    SettingLabel(title: Copy.text("Warnen bei niedrigem Akku", "Warn when low"),
                                 detail: Copy.text("Bei 20 % oder weniger.", "At 20% or less."),
                                 symbol: "exclamationmark.triangle.fill")
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct AccessoryRow: View {
    let gadget: Gadget
    @Bindable private var store = ConfigStore.shared
    private let hub = GadgetHub.shared

    var body: some View {
        let g = gadget
        HStack(spacing: 12) {
            Image(systemName: g.family.sfSymbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(g.connected ? Hue.accent : .secondary)
                .frame(width: 34, height: 34)
                .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(g.name).font(.body.weight(.medium)).lineLimit(1)
                Text(status).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            if let level = g.lowest {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(level) %").font(.system(.body, design: .rounded).weight(.semibold)).monospacedDigit()
                    Meter(fraction: Double(level) / 100, tint: Color(nsColor: GlyphPainter.levelColor(LevelBand(level: level))), thickness: 4)
                        .frame(width: 54)
                }
            }
            Menu {
                Toggle(Copy.text("In der Menüleiste zeigen", "Show in menu bar"), isOn: pinnedBinding)
                Toggle(Copy.text("Im Dashboard zeigen", "Show in dashboard"), isOn: visibleBinding)
                if !g.connected {
                    Divider()
                    Button(Copy.text("Vergessen", "Forget"), role: .destructive) { hub.forget(g.id) }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .opacity(g.connected ? 1 : 0.6)
        .padding(.vertical, 2)
    }

    private var status: String {
        let g = gadget
        guard g.connected else { return Copy.text("Nicht verbunden", "Not connected") }
        var parts = [Copy.text("Verbunden", "Connected")]
        if g.isPair { parts.append([g.leftBud.map { "L \($0) %" }, g.rightBud.map { "R \($0) %" }].compactMap { $0 }.joined(separator: " · ")) }
        if let c = g.caseLevel { parts.append(Copy.text("Case \(c) %", "Case \(c)%")) }
        if store.c.pinned.contains(g.id) { parts.append(Copy.text("in der Menüleiste", "in menu bar")) }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private var pinnedBinding: Binding<Bool> {
        Binding(get: { store.c.pinned.contains(gadget.id) },
                set: { on in store.c.pinned.removeAll { $0 == gadget.id }; if on { store.c.pinned.append(gadget.id) } })
    }

    private var visibleBinding: Binding<Bool> {
        Binding(get: { !store.c.hiddenGadgets.contains(gadget.id) },
                set: { on in store.c.hiddenGadgets.removeAll { $0 == gadget.id }; if !on { store.c.hiddenGadgets.append(gadget.id) } })
    }
}

// MARK: - History

private struct HistoryPrefs: View {
    @Bindable private var store = ConfigStore.shared
    @State private var confirmWipe = false
    @State private var wipeFailed = false

    var body: some View {
        Form {
            Section {
                Picker(selection: $store.c.keepDays) {
                    ForEach([7, 30, 90, 180, 365], id: \.self) { days in
                        Text(Copy.text("\(days) Tage", "\(days) days")).tag(days)
                    }
                } label: {
                    SettingLabel(title: Copy.text("Verlauf aufbewahren", "Keep history for"), symbol: "calendar")
                }
            } footer: {
                Text(Copy.text("Alle Daten bleiben auf diesem Mac. Volta hat kein Konto und keine Cloud.",
                               "All data stays on this Mac. Volta has no account and no cloud."))
            }

            Section(Copy.text("Daten", "Data")) {
                actionRow(Copy.text("Als CSV exportieren …", "Export as CSV …"), symbol: "square.and.arrow.up") { Journal.shared.exportCSV() }
                actionRow(Copy.text("Verlauf aus macOS übernehmen", "Import history from macOS"), symbol: "square.and.arrow.down") { Journal.shared.importSystemLog() }
                actionRow(Copy.text("Datenordner im Finder zeigen", "Show data folder in Finder"), symbol: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([store.folder])
                }
            }

            Section {
                Button(Copy.text("Verlauf löschen …", "Delete history …"), role: .destructive) { confirmWipe = true }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(Copy.text("Den gesamten Verlauf löschen?", "Delete the entire history?"), isPresented: $confirmWipe) {
            Button(Copy.text("Löschen", "Delete"), role: .destructive) { wipeFailed = !Journal.shared.wipe() }
        }
        .alert(Copy.text("Verlauf konnte nicht gelöscht werden", "History could not be deleted"), isPresented: $wipeFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(Copy.text("Volta konnte die Verlaufsdatei nicht schreiben. Bitte versuche es erneut.",
                           "Volta could not write the history file. Please try again."))
        }
    }

    private func actionRow(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                SettingLabel(title: title, symbol: symbol)
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - About

private struct AboutPrefs: View {
    private var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let short = info["CFBundleShortVersionString"] as? String ?? "–"
        let build = info["CFBundleVersion"] as? String ?? "–"
        return Copy.text("Version \(short) (Build \(build))", "Version \(short) (build \(build))")
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 104, height: 104)
                .shadow(color: .black.opacity(0.2), radius: 12, y: 5)
            Text("Volta").font(.system(size: 28, weight: .bold, design: .rounded))
            Text(version).foregroundStyle(.secondary)
            Text(Copy.text("Akku, Ladezyklen und Energieverbrauch – direkt in der Menüleiste.\nAlles bleibt auf deinem Mac.",
                           "Battery, charge cycles and energy use, right in the menu bar.\nEverything stays on your Mac."))
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Text("Copyright © 2026 Johannes Uth")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Window

@MainActor
final class PreferencesWindow {
    static let shared = PreferencesWindow()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: PreferencesView()))
            w.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.setContentSize(NSSize(width: 680, height: 700))
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        refreshTitle()
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    func refreshTitle() {
        window?.title = Copy.text("Volta – Einstellungen", "Volta Settings")
    }
}
