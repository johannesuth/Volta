import SwiftUI
import AppKit
import UniformTypeIdentifiers
import VoltaLanguageCore

enum PrefTab: String, CaseIterable, Identifiable {
    case general, menubar, dropdown, alerts, gadgets, data, about
    var id: Self { self }
    var title: String {
        ["general": Copy.text("Allgemein", "General"), "menubar": Copy.text("Menüleiste", "Menu Bar"),
         "dropdown": Copy.text("Dropdown", "Dashboard"), "alerts": Copy.text("Warnungen", "Alerts"),
         "gadgets": Copy.text("Zubehör", "Accessories"), "data": Copy.text("Daten", "Data"),
         "about": Copy.text("Info", "About")][rawValue]!
    }
    var symbol: String {
        ["general": "switch.2", "menubar": "menubar.rectangle", "dropdown": "rectangle.portrait.topthird.inset.filled",
         "alerts": "light.beacon.max.fill", "gadgets": "earbuds", "data": "externaldrive.fill", "about": "sparkles"][rawValue]!
    }
}

struct PreferencesView: View {
    @State private var tab: PrefTab = .general
    @Bindable private var store = ConfigStore.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(PrefTab.allCases) { t in
                    Button { withAnimation(.snappy) { tab = t } } label: {
                        VStack(spacing: 4) {
                            Image(systemName: t.symbol).font(.system(size: 16, weight: .medium)).frame(height: 20)
                            Text(t.title).font(.system(size: 11, weight: .medium))
                        }
                        .frame(width: 82, height: 50)
                        .foregroundStyle(tab == t ? Hue.accent : .secondary)
                        .background(tab == t ? Hue.accent.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                case .dropdown: DropdownPrefs()
                case .alerts: AlertPrefs()
                case .gadgets: GadgetPrefs()
                case .data: DataPrefs()
                case .about: AboutPrefs()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 640, minHeight: 600)
        .ignoresSafeArea(edges: .top)
        .environment(\.locale, Locale(identifier: store.c.language.localeIdentifier))
    }
}

// MARK: - General

private struct GeneralPrefs: View {
    @Bindable private var store = ConfigStore.shared
    @State private var autostart = LoginAgent.isInstalled
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section("Language") {
                Picker("App language", selection: $store.c.language) {
                    Text("Deutsch").tag(AppLanguage.german)
                    Text("English").tag(AppLanguage.english)
                }
                .pickerStyle(.segmented)
                .onChange(of: store.c.language) { _, _ in store.c.languageChosen = true }
            }
            Section("Start & Bedienung") {
                Toggle("Volta beim Anmelden starten", isOn: $autostart)
                    .onChange(of: autostart) { _, on in LoginAgent.install(on) }
                Toggle("Globaler Kurzbefehl öffnet das Dropdown", isOn: $store.c.shortcutOn)
                LabeledContent("Kurzbefehl") { ShortcutRecorder(combo: $store.c.shortcut) }
                    .disabled(!store.c.shortcutOn)
            }
            Section("Messung") {
                LabeledContent("Akku im Hintergrund alle") {
                    Slider(value: $store.c.pollSeconds, in: 5...120, step: 5) { EmptyView() }
                        .frame(width: 200)
                    Text("\(Int(store.c.pollSeconds)) s").monospacedDigit().frame(width: 44, alignment: .trailing)
                }
                LabeledContent("Zubehör scannen alle") {
                    Slider(value: $store.c.scanSeconds, in: 15...300, step: 15) { EmptyView() }
                        .frame(width: 200)
                    Text("\(Int(store.c.scanSeconds)) s").monospacedDigit().frame(width: 44, alignment: .trailing)
                }
                Text("Bei geöffnetem Dropdown misst Volta automatisch im Sekundentakt.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Darstellung") {
                Picker("Erscheinungsbild", selection: $store.c.look) {
                    ForEach(Look.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                LabeledContent("Akzentfarbe") {
                    HStack(spacing: 8) {
                        ForEach(Accent.allCases) { a in
                            Button { store.c.accent = a } label: {
                                Circle()
                                    .fill(Hue.swatch(a))
                                    .frame(width: 16, height: 16)
                                    .overlay(Circle().stroke(.primary.opacity(store.c.accent == a ? 0.9 : 0), lineWidth: 1.5).padding(-3))
                            }
                            .buttonStyle(.plain)
                            .help(a.title)
                        }
                    }
                }
                LabeledContent("Farbigkeit") {
                    Text("dezent").font(.caption).foregroundStyle(.secondary)
                    Slider(value: $store.c.vivid, in: 0...1) { EmptyView() }.frame(width: 180)
                    Text("kräftig").font(.caption).foregroundStyle(.secondary)
                }
                LabeledContent("Hintergrund") {
                    Text("klar").font(.caption).foregroundStyle(.secondary)
                    Slider(value: $store.c.panelTint, in: 0...0.9) { EmptyView() }.frame(width: 180)
                    Text("deckend").font(.caption).foregroundStyle(.secondary)
                }
                Picker("Temperatur", selection: $store.c.fahrenheit) {
                    Text("°C").tag(false)
                    Text("°F").tag(true)
                }
                .pickerStyle(.segmented)
                Toggle("Watt mit Nachkommastelle", isOn: $store.c.showDecimals)
            }
            Section {
                Button("Alle Einstellungen zurücksetzen …", role: .destructive) { confirmReset = true }
                    .confirmationDialog("Wirklich alles zurücksetzen?", isPresented: $confirmReset) {
                        Button("Zurücksetzen", role: .destructive) { store.restoreDefaults() }
                    } message: { Text("Verlauf und bekanntes Zubehör bleiben erhalten.") }
            }
        }
        .formStyle(.grouped)
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
            Text(listening ? "Tasten drücken …" : combo.label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .frame(minWidth: 110)
        }
        .buttonStyle(.bordered)
        .tint(listening ? Hue.warn : nil)
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
    private let telemetry = Telemetry.shared
    private let hub = GadgetHub.shared

    var body: some View {
        Form {
            Section(Copy.text("Stil", "Style")) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(GlyphStyle.allCases) { style in
                        Button { store.c.glyph = style } label: {
                            VStack(spacing: 6) {
                                sample(style, dark: true)
                                    .frame(maxWidth: .infinity, minHeight: 34)
                                    .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 7))
                                Text(style.title).font(.system(size: 11, weight: .medium))
                            }
                            .padding(8)
                            .background(store.c.glyph == style ? Hue.accent.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(store.c.glyph == style ? Hue.accent : .secondary.opacity(0.25)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            Section(Copy.text("Optionen", "Options")) {
                Picker(Copy.text("Menüleistenfarbe", "Menu bar icon color"), selection: $store.c.glyphTint) {
                    ForEach(GlyphTint.allCases) { tint in
                        HStack(spacing: 7) {
                            Circle().fill(swatchColor(for: tint)).frame(width: 9, height: 9)
                            Text(tint.title)
                        }
                        .tag(tint)
                    }
                }
                Toggle(Copy.text("Leistung in Watt anzeigen", "Show power in watts"), isOn: $store.c.glyphWatts)
                Toggle(Copy.text("Ladestand bei 100 % am Netzteil ausblenden", "Hide level when full and plugged in"), isOn: $store.c.glyphQuietWhenFull)
                LabeledContent("Vorschau") {
                    HStack(spacing: 10) {
                        sample(store.c.glyph, dark: false)
                            .padding(.horizontal, 10).padding(.vertical, 3)
                            .background(.white, in: RoundedRectangle(cornerRadius: 6))
                        sample(store.c.glyph, dark: true)
                            .padding(.horizontal, 10).padding(.vertical, 3)
                            .background(.black, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            Section(Copy.text("Zubehör neben dem Symbol", "Accessories next to the icon")) {
                if hub.all.isEmpty { Text("Noch kein Zubehör erkannt.").foregroundStyle(.secondary) }
                ForEach(hub.all) { g in
                    Toggle(isOn: Binding(get: { store.c.pinned.contains(g.id) },
                                         set: { on in store.c.pinned.removeAll { $0 == g.id }; if on { store.c.pinned.append(g.id) } })) {
                        Label(g.name, systemImage: g.family.sfSymbol)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func sample(_ style: GlyphStyle, dark: Bool) -> some View {
        var cfg = store.c
        cfg.glyph = style
        var s = telemetry.now
        if !s.hasPack { s.hasPack = true; s.level = 75 }
        let image = GlyphPainter.image(snapshot: s, clock: telemetry.compactTime, cfg: cfg, darkBar: dark, badges: [])
        return Image(nsImage: image)
            .renderingMode(image.isTemplate ? .template : .original)
            .foregroundStyle(dark ? Color.white : Color.black)
    }

    private func swatchColor(for tint: GlyphTint) -> Color {
        if tint == .status { return Hue.good }
        return GlyphPainter.color(for: tint).map(Color.init(nsColor:)) ?? .gray
    }
}

// MARK: - Dropdown

private struct DropdownPrefs: View {
    @Bindable private var store = ConfigStore.shared

    var body: some View {
        Form {
            Section {
                Toggle(Copy.text("Offen halten, wenn daneben geklickt wird", "Keep open when clicking elsewhere"),
                       isOn: $store.c.stickyDropdown)
            } header: {
                Text(Copy.text("Verhalten", "Behavior"))
            } footer: {
                Text(Copy.text("Bereiche lassen sich mit einem Klick auf die Überschrift auf- und zuklappen, auch mehrere gleichzeitig.",
                               "Click a section title to expand or collapse it; several can be open at once."))
            }

            Section {
                ForEach([TileKind.vitals, .trend, .gadgets]) { tile in tileToggle(tile) }
            } header: {
                Text(Copy.text("Bereiche", "Sections"))
            }

            Section {
                ForEach([TileKind.balance, .apps]) { tile in tileToggle(tile) }
                Toggle(isOn: $store.c.showBatteryDetails) {
                    Label(Copy.text("Technische Akkuwerte (mAh, Spannung, Strom)", "Technical battery values (mAh, voltage, current)"),
                          systemImage: "gauge.with.dots.needle.33percent")
                }
            } header: {
                Text(Copy.text("Für Fortgeschrittene", "Advanced"))
            } footer: {
                Text(Copy.text("Diese Werte sind standardmäßig ausgeschaltet.", "These are off by default."))
            }

            Section {
                Picker(Copy.text("Verlauf", "History range"), selection: $store.c.chartSpan) {
                    ForEach(ChartSpan.allCases) { Text($0.title).tag($0) }
                }
                Stepper(Copy.text("Angezeigte Apps: \(store.c.appRows)", "Apps shown: \(store.c.appRows)"),
                        value: $store.c.appRows, in: 3...6)
                Picker(Copy.text("Zubehör sortieren", "Sort accessories"), selection: $store.c.gadgetOrder) {
                    ForEach(GadgetOrder.allCases) { Text($0.title).tag($0) }
                }
            } header: {
                Text(Copy.text("Inhalte", "Content"))
            }
        }
        .formStyle(.grouped)
    }

    private func tileToggle(_ tile: TileKind) -> some View {
        Toggle(isOn: Binding(get: { !store.c.hiddenTiles.contains(tile) },
                             set: { store.toggleTile(tile, on: $0) })) {
            Label(tile.title, systemImage: tile.icon)
        }
    }
}

// MARK: - Alerts

private struct AlertPrefs: View {
    @Bindable private var store = ConfigStore.shared
    @State private var tones = Chime.catalog()

    var body: some View {
        Form {
            Section {
                ForEach($store.c.triggers) { $t in
                    TriggerRow(trigger: $t, tones: tones) { store.c.triggers.removeAll { $0.id == t.id } }
                }
                HStack {
                    Button(Copy.text("Entladewarnung hinzufügen", "Add low-battery alert"), systemImage: "arrow.down.circle") {
                        store.c.triggers.append(Trigger(direction: .down, level: 30, presentation: .aura, tone: "Tink"))
                    }
                    Button(Copy.text("Ladeziel hinzufügen", "Add charge target"), systemImage: "arrow.up.circle") {
                        store.c.triggers.append(Trigger(direction: .up, level: 90, presentation: .card, tone: "Ping"))
                    }
                    Spacer()
                    Button("Vorgaben") { store.c.triggers = Trigger.starterSet }
                }
                .buttonStyle(.borderless)
            } header: {
                Text("Regeln")
            } footer: {
                Text("Eine Regel greift, wenn der Ladestand ihre Schwelle überschreitet – nicht bei jedem Messwert.")
            }

            Section("Auftritt") {
                Picker("Leuchtrahmen", selection: $store.c.aura) { ForEach(AuraStrength.allCases) { Text($0.title).tag($0) } }
                    .pickerStyle(.segmented)
                Picker("Hinweiskarte", selection: $store.c.cardPlacement) { ForEach(CardPlacement.allCases) { Text($0.title).tag($0) } }
                LabeledContent("Anzeigedauer") {
                    Slider(value: $store.c.cardSeconds, in: 3...30, step: 1) { EmptyView() }.frame(width: 200)
                    Text("\(Int(store.c.cardSeconds)) s").monospacedDigit().frame(width: 40, alignment: .trailing)
                }
                LabeledContent("Wiederholung frühestens nach") {
                    Slider(value: $store.c.cooldownMinutes, in: 1...60, step: 1) { EmptyView() }.frame(width: 200)
                    Text("\(Int(store.c.cooldownMinutes)) min").monospacedDigit().frame(width: 52, alignment: .trailing)
                }
                Toggle("Zusätzlich in der Mitteilungszentrale", isOn: $store.c.bannerAlso)
            }

            Section("Ton") {
                LabeledContent("Lautstärke") {
                    Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                    Slider(value: $store.c.volume, in: 0...1) { EmptyView() }.frame(width: 200)
                    Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                }
                Toggle("Ton beim Ein- und Ausstecken", isOn: $store.c.plugTone)
                Toggle("Ruhezeit (stumm)", isOn: $store.c.quiet.enabled)
                if store.c.quiet.enabled {
                    HStack {
                        Picker("von", selection: $store.c.quiet.fromHour) { ForEach(0..<24, id: \.self) { Text("\($0):00").tag($0) } }
                        Picker("bis", selection: $store.c.quiet.toHour) { ForEach(0..<24, id: \.self) { Text("\($0):00").tag($0) } }
                    }
                }
                Button("Eigenen Ton hinzufügen …") { importTone() }
            }

            Section("Zubehör") {
                LabeledContent("Warnen unter") {
                    Slider(value: Binding(get: { Double(store.c.gadgetFloor) }, set: { store.c.gadgetFloor = Int($0) }),
                           in: 0...50, step: 5) { EmptyView() }.frame(width: 200)
                    Text(store.c.gadgetFloor == 0 ? "aus" : "\(store.c.gadgetFloor) %").monospacedDigit().frame(width: 44, alignment: .trailing)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func importTone() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        panel.urls.forEach { _ = try? Chime.adopt($0) }
        tones = Chime.catalog()
    }
}

private struct TriggerRow: View {
    @Binding var trigger: Trigger
    var tones: [String]
    var remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Toggle("", isOn: $trigger.active).labelsHidden().toggleStyle(.switch).controlSize(.mini)
                Picker("", selection: $trigger.direction) {
                    Label("Fällt unter", systemImage: "arrow.down").tag(Trigger.Direction.down)
                    Label("Steigt auf", systemImage: "arrow.up").tag(Trigger.Direction.up)
                }
                .labelsHidden().fixedSize()
                Slider(value: Binding(get: { Double(trigger.level) }, set: { trigger.level = Int($0) }), in: 1...100, step: 1) { EmptyView() }
                Text("\(trigger.level) %").font(.system(.body, design: .rounded).weight(.semibold)).monospacedDigit().frame(width: 46)
                Button {
                    var s = Telemetry.shared.now
                    s.minutesToEmpty = s.minutesToEmpty ?? 42
                    Sentinel.shared.stage(trigger, level: trigger.level, snapshot: s, preview: true)
                } label: { Image(systemName: "play.circle.fill") }
                    .help("Vorschau")
                Button(role: .destructive, action: remove) { Image(systemName: "minus.circle") }.help("Entfernen")
            }
            .buttonStyle(.borderless)
            HStack(spacing: 10) {
                Picker("Anzeige", selection: $trigger.presentation) { ForEach(Presentation.allCases) { Text($0.title).tag($0) } }
                    .fixedSize()
                Picker("Ton", selection: $trigger.tone) {
                    ForEach(tones, id: \.self) { tone in
                        Text(tone == Chime.silent ? Copy.text("Stumm", "Silent") : tone).tag(tone)
                    }
                }
                    .fixedSize()
                    .onChange(of: trigger.tone) { _, t in Chime.ring(t, force: true) }
                Toggle(Copy.text("Hinweis länger anzeigen", "Keep alert visible longer"), isOn: $trigger.lingers).toggleStyle(.checkbox)
            }
            .controlSize(.small)
        }
        .opacity(trigger.active ? 1 : 0.55)
        .padding(.vertical, 3)
    }
}

// MARK: - Gadgets

private struct GadgetPrefs: View {
    @Bindable private var store = ConfigStore.shared
    private let hub = GadgetHub.shared

    var body: some View {
        Form {
            Section {
                if hub.all.isEmpty {
                    Text(Copy.text("Volta liest Akkustände direkt aus macOS. Dafür ist keine Bluetooth-Freigabe nötig. Verbinde ein Gerät mit Akku, damit es hier erscheint.", "Volta reads battery levels directly from macOS, without Bluetooth permission. Connect a battery-powered device to see it here."))
                        .foregroundStyle(.secondary)
                }
                ForEach(hub.all) { g in
                    HStack {
                        Image(systemName: g.family.sfSymbol).frame(width: 24).foregroundStyle(Hue.level(g.lowest))
                        VStack(alignment: .leading) {
                            Text(g.name)
                            Text(g.connected ? Copy.text("verbunden · \(g.lowest.map { "\($0) %" } ?? "–")",
                                                         "connected · \(g.lowest.map { "\($0)%" } ?? "–")")
                                             : Copy.text("nicht verbunden", "not connected"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("Im Dropdown", isOn: Binding(get: { !store.c.hiddenGadgets.contains(g.id) },
                                                            set: { on in store.c.hiddenGadgets.removeAll { $0 == g.id }; if !on { store.c.hiddenGadgets.append(g.id) } }))
                        .toggleStyle(.checkbox)
                        Button("Vergessen") { hub.forget(g.id) }.buttonStyle(.borderless).disabled(g.connected)
                    }
                }
            } header: {
                HStack {
                    Text("Bekanntes Zubehör")
                    Spacer()
                    Button("Jetzt suchen") { Task { await hub.rescan() } }.controlSize(.small)
                }
            }
            Section { Button("Bluetooth-Einstellungen öffnen") { Shortcuts.bluetoothPane() } }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Data

private struct DataPrefs: View {
    @Bindable private var store = ConfigStore.shared
    @State private var confirmWipe = false
    @State private var wipeFailed = false

    var body: some View {
        Form {
            Section("Verlauf") {
                Picker(Copy.text("Aufbewahrungsdauer", "Keep history for"), selection: $store.c.keepDays) {
                    ForEach([7, 30, 90, 180, 365], id: \.self) { days in
                        Text(Copy.text("\(days) Tage", "\(days) days")).tag(days)
                    }
                }
                Button("Als CSV exportieren …") { Journal.shared.exportCSV() }
                Button(Copy.text("Energieverlauf aus macOS importieren", "Import macOS power history")) { Journal.shared.importSystemLog() }
                Button("Verlauf löschen …", role: .destructive) { confirmWipe = true }
                    .confirmationDialog("Den gesamten Verlauf löschen?", isPresented: $confirmWipe) {
                        Button("Löschen", role: .destructive) { wipeFailed = !Journal.shared.wipe() }
                    }
            }
            Section("Speicherort") {
                LabeledContent("Ordner") { Text(store.folder.path(percentEncoded: false)).font(.caption).textSelection(.enabled) }
                Button("Im Finder zeigen") { NSWorkspace.shared.activateFileViewerSelecting([store.folder]) }
                Text(Copy.text("Alle Daten bleiben auf diesem Mac: config.json, journal.jsonl, gadgets.json, history-cleared.marker und eigene Töne.", "All data stays on this Mac: config.json, journal.jsonl, gadgets.json, history-cleared.marker and custom sounds."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .alert("Verlauf konnte nicht gelöscht werden", isPresented: $wipeFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Volta konnte die Verlaufsdatei nicht schreiben. Prüfe den Speicherort und versuche es erneut.")
        }
    }
}

// MARK: - About

private struct AboutPrefs: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 110, height: 110)
                .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
            Text("Volta").font(.system(size: 30, weight: .heavy, design: .rounded))
            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")")
                .foregroundStyle(.secondary)
            Text("Ladestand, Leistung, Verlauf und Zubehör – direkt aus der Menüleiste.\nKein Hintergrund-Helfer, keine Cloud.")
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
            w.title = Copy.text("Volta Einstellungen", "Volta Settings")
            w.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.setContentSize(NSSize(width: 700, height: 660))
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        window?.appearance = ConfigStore.shared.c.look.appearance
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
