// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import SwiftUI
import Charts
import VoltaLanguageCore

// MARK: - Root

struct DropdownRoot: View {
    var onSize: (CGSize) -> Void
    var openPreferences: () -> Void
    var dismiss: () -> Void

    @Bindable private var store = ConfigStore.shared

    var body: some View {
        let cfg = store.c
        let dim = Dim()
        VStack(spacing: dim(6)) {
            Masthead(openPreferences: openPreferences)
            ForEach(store.shownTiles) { kind in
                switch kind {
                case .charge: ChargeTile()
                case .balance: BalanceTile()
                case .trend: TrendTile()
                case .vitals: VitalsTile()
                case .gadgets: GadgetTile()
                case .apps: AppsTile()
                }
            }
            DockBar(dismiss: dismiss)
        }
        .padding(dim(9))
        .frame(width: dim(Dim.panelWidth))
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGSize.self, of: { $0.size }) { onSize($0) }
        .glassPlate(radius: dim(18))
        .clipShape(.rect(cornerRadius: dim(18)))
        .overlay(RoundedRectangle(cornerRadius: dim(18), style: .continuous).stroke(.primary.opacity(0.07), lineWidth: 0.5))
        .environment(\.dim, dim)
        .environment(\.locale, Locale(identifier: cfg.language.localeIdentifier))
        .environment(\.tileExpansion, $store.c.expansion)
        .tint(Hue.accent)
        .animation(.snappy(duration: 0.18), value: store.c.expansion)
    }
}

// MARK: - Masthead

private struct Masthead: View {
    var openPreferences: () -> Void
    @Environment(\.dim) private var dim
    @Bindable private var store = ConfigStore.shared

    var body: some View {
        HStack(spacing: dim(6)) {
            Image(systemName: "bolt.fill")
                .font(dim.text(11, .semibold))
                .foregroundStyle(Hue.accent)
            Text("Volta").font(dim.text(13, .semibold))
            Spacer(minLength: dim(4))
            iconButton(store.c.stickyDropdown ? "pin.fill" : "pin", tint: store.c.stickyDropdown ? Hue.accent : .secondary) {
                store.c.stickyDropdown.toggle()
            }
            .help(Copy.text("Fenster offen halten", "Keep panel open"))
            iconButton("gearshape", action: openPreferences)
                .help(Copy.text("Einstellungen (⌘,)", "Settings (⌘,)"))
                .keyboardShortcut(",", modifiers: .command)
        }
        .padding(.horizontal, dim(4))
        .padding(.top, dim(2))
    }

    private func iconButton(_ symbol: String, tint: Color = .secondary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(dim.text(10.5, .medium))
                .foregroundStyle(tint)
                .frame(width: dim(22), height: dim(22))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Charge

private struct ChargeTile: View {
    @Environment(\.dim) private var dim
    private let telemetry = Telemetry.shared

    var body: some View {
        let s = telemetry.now
        let stateColor = s.mode == .deficit ? Hue.warn : Hue.accent
        Tile(tint: Hue.accent) {
            HStack(alignment: .center) {
                HStack(alignment: .firstTextBaseline, spacing: dim(2)) {
                    Text("\(s.level)")
                        .font(dim.number(35, .semibold))
                        .contentTransition(.numericText(value: Double(s.level)))
                    Text("%").font(dim.text(16, .medium)).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: dim(3)) {
                    Label(modeTitle(s.mode), systemImage: modeSymbol(s.mode))
                        .font(dim.text(10.5, .medium))
                        .foregroundStyle(stateColor)
                    if let remaining = telemetry.compactTime,
                       let minutes = s.mode == .filling ? s.minutesToFull : s.minutesToEmpty {
                        let clock = ClockText.until(minutes: minutes, language: ConfigStore.shared.c.language)
                        HStack(alignment: .firstTextBaseline, spacing: dim(5)) {
                            Text(Copy.text(s.mode == .filling ? "Voll in" : "Verbleibend",
                                           s.mode == .filling ? "Time to full" : "Time left"))
                                .font(dim.text(9.5)).foregroundStyle(.secondary)
                            Text(remaining).font(dim.number(13, .medium))
                        }
                        Text(Copy.text(s.mode == .filling ? "voll um \(clock)" : "bis ca. \(clock)",
                                       s.mode == .filling ? "full at \(clock)" : "until about \(clock)"))
                            .font(dim.text(9.5)).foregroundStyle(.secondary)
                    }
                }
            }
            Meter(fraction: Double(s.level) / 100, tint: Hue.accent, thickness: dim(4))
        }
        .animation(.smooth(duration: 0.35), value: s.level)
    }

    private func modeTitle(_ m: FlowMode) -> String {
        switch m {
        case .draining: Copy.text("Akkubetrieb", "Battery")
        case .filling: Copy.text("Lädt", "Charging")
        case .resting: Copy.text("Pausiert", "Paused")
        case .topped: Copy.text("Voll", "Full")
        case .deficit: Copy.text("Netzteil zu schwach", "Power deficit")
        case .mainsOnly: Copy.text("Netzbetrieb", "Adapter")
        }
    }

    private func modeSymbol(_ m: FlowMode) -> String {
        switch m {
        case .draining: "battery.75percent"
        case .filling: "bolt.fill"
        case .resting: "pause.fill"
        case .topped: "checkmark"
        case .deficit: "exclamationmark.triangle.fill"
        case .mainsOnly: "powerplug.fill"
        }
    }
}

// MARK: - Power balance

private struct BalanceTile: View {
    @Environment(\.dim) private var dim
    private let telemetry = Telemetry.shared

    var body: some View {
        let s = telemetry.now
        let inflow = s.mainsWatts + max(0, -s.packWatts)
        let scale = max(inflow, s.systemWatts + max(0, s.packWatts), 1)
        Tile(kind: .balance) {
            row(s.onMains ? Copy.text("Vom Netzteil", "From adapter") : Copy.text("Aus dem Akku", "From battery"), s.onMains ? "powerplug.fill" : "battery.75percent", inflow, scale)
            row(Copy.text("Verbrauch des Mac", "Mac usage"), "laptopcomputer", s.systemWatts, scale)
            if s.packWatts > 0.3 { row(Copy.text("In den Akku", "Into battery"), "arrow.down.to.line", s.packWatts, scale) }
            if let note = verdict(s) {
                Label(note.0, systemImage: note.1)
                    .font(dim.text(10.5, .medium))
                    .foregroundStyle(note.2)
            }
        }
    }

    private func row(_ title: String, _ icon: String, _ watts: Double, _ scale: Double) -> some View {
        VStack(alignment: .leading, spacing: dim(5)) {
            HStack(spacing: dim(5)) {
                Image(systemName: icon).font(dim.text(9.5, .medium)).foregroundStyle(.secondary).frame(width: dim(14))
                Text(title).font(dim.text(11))
                Spacer()
                Text(String(format: "%.1f W", watts)).font(dim.number(11.5, .medium))
            }
            Meter(fraction: watts / scale, tint: Hue.accent, thickness: dim(4))
        }
    }

    private func verdict(_ s: PowerSnapshot) -> (String, String, Color)? {
        switch s.mode {
        case .deficit: return (Copy.text("Netzteil zu schwach – der Akku entlädt sich", "Adapter cannot keep up — battery is helping"), "exclamationmark.triangle.fill", Hue.amber)
        case .resting: return (Copy.text("Laden pausiert, um den Akku zu schonen", "Charging paused to protect the battery"), "leaf.fill", Hue.mint)
        case .filling:
            guard let w = s.charger?.ratedWatts else { return nil }
            return w < 30 ? (Copy.text("Langsames Laden mit \(w)-W-Netzteil", "Low-power \(w) W adapter — charging slowly"), "tortoise.fill", Hue.amber)
                          : (Copy.text("\(w)-W-Netzteil angeschlossen", "\(w) W adapter connected"), "powerplug.fill", Hue.mint)
        default: return nil
        }
    }
}

// MARK: - Trend chart

/// Time-axis captions in the app's own language rather than the system locale.
enum ChartAxisLabel {
    static func text(for date: Date, span: ChartSpan, language: AppLanguage) -> String {
        let style = Date.FormatStyle(locale: Locale(identifier: language.localeIdentifier))
        if span == .week { return date.formatted(style.weekday(.abbreviated)) }
        return language == .german
            ? date.formatted(style.hour(.twoDigits(amPM: .omitted)))
            : date.formatted(Date.FormatStyle(locale: Locale(identifier: "en_US")).hour(.defaultDigits(amPM: .abbreviated)))
    }
}

private struct TrendTile: View {
    @Environment(\.dim) private var dim
    @Environment(\.tileExpansion) private var expansion
    @Bindable private var store = ConfigStore.shared
    @State private var marks: [Mark] = []
    @State private var hovered: Mark?
    private let telemetry = Telemetry.shared
    private var span: ChartSpan { store.c.chartSpan }
    private var open: Bool { expansion.wrappedValue.contains(.trend) }

    private let batteryColor = Hue.accent
    private let chargingColor = Hue.good

    var body: some View {
        Tile(kind: .trend, trailing: open ? AnyView(SpanSwitch(span: $store.c.chartSpan)) : nil) {
            if marks.count < 2 {
                Text(Copy.text("Der Verlauf erscheint, sobald ein paar Messpunkte gesammelt sind.",
                               "History appears after a few measurements are collected."))
                    .font(dim.text(11)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: dim(70), alignment: .leading)
            } else {
                chart
                    .frame(height: dim(Dim.chartHeight))
                legend
                HStack(spacing: dim(10)) {
                    Figure(caption: Copy.text("Ø Entladung", "Avg. discharge"), value: Journal.lossPerHour(marks.filter { $0.w != nil }).map {
                        Copy.text(String(format: "%.1f %%/Std.", $0), String(format: "%.1f %%/hr", $0))
                    } ?? "–",
                           icon: "chart.line.downtrend.xyaxis", tint: Hue.accent)
                    Figure(caption: Copy.text("Mit voller Ladung", "Full-charge runtime"), value: fullChargeRuntime.map(Telemetry.span) ?? "–",
                           icon: "battery.100percent", tint: Hue.accent)
                }
            }
        }
        .task(id: "\(span.rawValue)-\(open)") {
            if open { reload() }
        }
        .onChange(of: telemetry.now.level) {
            if open { reload() }
        }
    }

    private var chart: some View {
        let segments = TrendSegment.split(marks, maxGap: span.maxGap)
        let last = marks.last
        return Chart {
            ForEach(segments) { segment in
                let color = segment.charging ? chargingColor : batteryColor
                ForEach(segment.points, id: \.t) { m in
                    AreaMark(x: .value("t", m.date), yStart: .value("0", 0), yEnd: .value("%", m.p),
                             series: .value("s", segment.id))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(LinearGradient(colors: [color.opacity(0.30), color.opacity(0.02)],
                                                        startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("t", m.date), y: .value("%", m.p), series: .value("s", segment.id))
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: dim(2.2), lineCap: .round, lineJoin: .round))
                        .foregroundStyle(color)
                }
            }
            if let hovered {
                RuleMark(x: .value("t", hovered.date))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .annotation(position: .top, spacing: dim(2),
                                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        Text(TrendReadout.text(level: hovered.p, at: hovered.date, span: span, language: store.c.language))
                            .font(dim.number(9.5, .semibold))
                            .padding(.horizontal, dim(7)).padding(.vertical, dim(3))
                            .background(.regularMaterial, in: Capsule())
                            .overlay(Capsule().stroke(.primary.opacity(0.1), lineWidth: 0.5))
                    }
                PointMark(x: .value("t", hovered.date), y: .value("%", hovered.p))
                    .symbolSize(dim(45))
                    .foregroundStyle(hovered.ac ? chargingColor : batteryColor)
            } else if let last {
                let color = last.ac ? chargingColor : batteryColor
                PointMark(x: .value("t", last.date), y: .value("%", last.p))
                    .symbolSize(dim(150))
                    .foregroundStyle(color.opacity(0.22))
                PointMark(x: .value("t", last.date), y: .value("%", last.p))
                    .symbolSize(dim(40))
                    .foregroundStyle(color)
            }
        }
        .chartYScale(domain: 0...100)
        .chartXScale(domain: (Date.now - span.interval)...Date.now)
        .chartYAxis {
            AxisMarks(position: .trailing, values: [0, 50, 100]) { v in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(.primary.opacity(0.08))
                AxisValueLabel {
                    Text("\(v.as(Int.self) ?? 0)").font(dim.number(8.5, .medium)).foregroundStyle(Color.secondary)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: span == .week ? .day : .hour, count: span == .week ? 1 : (span == .day ? 6 : 2))) { v in
                AxisValueLabel(collisionResolution: .greedy) {
                    if let d = v.as(Date.self) {
                        Text(ChartAxisLabel.text(for: d, span: span, language: store.c.language))
                            .font(dim.text(8.5))
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let point):
                            guard let plot = proxy.plotFrame else { return }
                            let x = point.x - geometry[plot].origin.x
                            guard let date: Date = proxy.value(atX: x) else { return }
                            hovered = marks.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
                        case .ended:
                            hovered = nil
                        }
                    }
            }
        }
        .animation(.easeOut(duration: 0.12), value: hovered)
    }

    private var legend: some View {
        HStack(spacing: dim(12)) {
            legendItem(batteryColor, Copy.text("Akkubetrieb", "On battery"))
            legendItem(chargingColor, Copy.text("Am Netzteil", "Charging"))
            Spacer(minLength: 0)
        }
    }

    private func legendItem(_ color: Color, _ title: String) -> some View {
        HStack(spacing: dim(5)) {
            Capsule().fill(color).frame(width: dim(12), height: dim(3))
            Text(title).font(dim.text(9)).foregroundStyle(.secondary)
        }
    }

    /// Whole-pack runtime at the current draw: stored energy (Wh) ÷ smoothed watts.
    private var fullChargeRuntime: Int? {
        let s = telemetry.now
        let draw = -telemetry.calmPackWatts
        guard !s.onMains, draw > 1, s.fullMAh > 0, s.volts > 0 else { return nil }
        return Int(Double(s.fullMAh) * s.volts / 1000 / draw * 60)
    }

    private func reload() {
        var list = Journal.shared.marks(since: .now - store.c.chartSpan.interval)
        let s = telemetry.now
        if s.hasPack { list.append(Mark(t: Date.now.timeIntervalSince1970, p: s.level, ac: s.onMains, w: nil, c: nil)) }
        marks = list
    }
}

/// Three small pills to pick the chart range, with a sliding highlight.
private struct SpanSwitch: View {
    @Binding var span: ChartSpan
    @Environment(\.dim) private var dim
    @Namespace private var highlight

    var body: some View {
        HStack(spacing: dim(1)) {
            ForEach(ChartSpan.allCases) { option in
                let selected = option == span
                Button {
                    withAnimation(.snappy(duration: 0.22)) { span = option }
                } label: {
                    Text(option.shortTitle)
                        .font(dim.text(9, selected ? .semibold : .medium))
                        .foregroundStyle(selected ? Color.primary : Color.secondary)
                        .padding(.horizontal, dim(7))
                        .padding(.vertical, dim(3))
                        .background {
                            if selected {
                                Capsule()
                                    .fill(Hue.accent.opacity(0.32))
                                    .matchedGeometryEffect(id: "pill", in: highlight)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(dim(2))
        .background(Capsule().fill(.primary.opacity(0.07)))
        .fixedSize()
    }
}

// MARK: - Vitals

private struct VitalsTile: View {
    @Environment(\.dim) private var dim
    private let telemetry = Telemetry.shared
    private let store = ConfigStore.shared

    var body: some View {
        let s = telemetry.now
        let wear = s.wear ?? 100
        let healthy = wear >= 80
        Tile(kind: .vitals, trailing: AnyView(
            Text(telemetry.wearVerdict)
                .font(dim.text(10.5, .medium))
                .foregroundStyle(healthy ? Hue.mint : Hue.amber)
                .padding(.horizontal, dim(8)).padding(.vertical, dim(3))
                .background((healthy ? Hue.mint : Hue.amber).opacity(0.14), in: Capsule())
        )) {
            HStack(alignment: .firstTextBaseline, spacing: dim(3)) {
                Text(String(format: "%.0f", wear)).font(dim.number(23, .bold))
                Text(Copy.text("% maximale Kapazität", "% maximum capacity")).font(dim.text(11)).foregroundStyle(.secondary)
                Spacer()
            }
            Meter(fraction: wear / 100, tint: Hue.accent, thickness: dim(4))
            Grid(alignment: .leading, horizontalSpacing: dim(10), verticalSpacing: dim(7)) {
                GridRow {
                    Figure(caption: Copy.text("Ladezyklen", "Charge cycles"), value: "\(s.cycles)", icon: "arrow.triangle.2.circlepath", tint: Hue.accent)
                    Figure(caption: Copy.text("Temperatur", "Temperature"), value: s.celsius.map(store.degrees) ?? "–", icon: "thermometer.medium", tint: Hue.accent)
                }
                if store.c.showBatteryDetails {
                    GridRow {
                        Figure(caption: Copy.text("Kapazität jetzt / ab Werk", "Full / design capacity"), value: "\(s.fullMAh) / \(s.designMAh) mAh", icon: "battery.100percent", tint: Hue.accent)
                        Figure(caption: Copy.text("Spannung · Strom", "Voltage · current"), value: String(format: "%.2f V · %.0f mA", s.volts, s.milliamps), icon: "bolt.fill", tint: Hue.accent)
                    }
                }
            }
        }
    }
}

// MARK: - Gadgets

private struct GadgetTile: View {
    @Environment(\.dim) private var dim
    private let hub = GadgetHub.shared
    private let store = ConfigStore.shared

    var body: some View {
        let list = hub.visible
        Tile(kind: .gadgets) {
            if list.isEmpty {
                Text(Copy.text("Kein Zubehör mit Akku verbunden.", "No battery accessory connected."))
                    .font(dim.text(11)).foregroundStyle(.secondary)
            } else {
                VStack(spacing: dim(10)) { ForEach(list) { row($0) } }
            }
        }
    }

    private func row(_ g: Gadget) -> some View {
        let tint = Hue.level(g.lowest)
        return HStack(spacing: dim(10)) {
            Image(systemName: g.family.sfSymbol)
                .font(dim.text(12, .medium))
                .foregroundStyle(Hue.accent)
                .frame(width: dim(28), height: dim(28))
            VStack(alignment: .leading, spacing: dim(4)) {
                HStack {
                    Text(g.name).font(dim.text(12, .medium)).lineLimit(1)
                    Spacer(minLength: 0)
                    if g.isPair {
                        Text([g.leftBud.map { "L \($0)" }, g.rightBud.map { "R \($0)" }].compactMap { $0 }.joined(separator: "  "))
                            .font(dim.number(11.5, .semibold)).foregroundStyle(tint)
                    } else if let v = g.lowest {
                        Text("\(v) %").font(dim.number(12, .semibold)).foregroundStyle(tint)
                    }
                }
                if let v = g.lowest {
                    Meter(fraction: Double(v) / 100, tint: Hue.accent, thickness: dim(3))
                }
                Text(status(g)).font(dim.text(10)).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .opacity(g.connected ? 1 : 0.45)
        .contextMenu {
            Button(store.c.pinned.contains(g.id) ? Copy.text("Nicht mehr in der Menüleiste", "Remove from menu bar")
                                                 : Copy.text("In der Menüleiste zeigen", "Show in menu bar")) {
                if let i = store.c.pinned.firstIndex(of: g.id) { store.c.pinned.remove(at: i) } else { store.c.pinned.append(g.id) }
            }
            Button(Copy.text("Ausblenden", "Hide")) { store.c.hiddenGadgets.append(g.id) }
            if !g.connected { Button(Copy.text("Vergessen", "Forget"), role: .destructive) { hub.forget(g.id) } }
        }
    }

    private func status(_ g: Gadget) -> String {
        guard g.connected else {
            let formatter = RelativeDateTimeFormatter()
            formatter.locale = Locale(identifier: store.c.language.localeIdentifier)
            formatter.unitsStyle = .abbreviated
            let relative = formatter.localizedString(for: g.lastSeen, relativeTo: .now)
            return Copy.text("zuletzt \(relative)", "last seen \(relative)")
        }
        var parts = [Copy.text("verbunden", "connected")]
        if let c = g.caseLevel { parts.append(Copy.text("Ladecase \(c) %", "Case \(c)%")) }
        if store.c.pinned.contains(g.id) { parts.append(Copy.text("in der Menüleiste", "in the menu bar")) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Apps

private struct AppsTile: View {
    @Environment(\.dim) private var dim
    private let ledger = PowerLedger.shared
    private let store = ConfigStore.shared

    var body: some View {
        let rows = Array(ledger.ranking.prefix(store.c.appRows))
        Tile(kind: .apps, trailing: AnyView(
            Text(Copy.text("Anteil", "Share"))
                .font(dim.text(10.5, .medium)).foregroundStyle(.secondary)
        )) {
            if rows.isEmpty {
                Label(Copy.text("Noch keine Verbrauchsdaten für Apps verfügbar.", "No app energy data yet."),
                      systemImage: "chart.bar.xaxis")
                    .font(dim.text(11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: dim(10)) {
                ForEach(rows) { c in
                    HStack(spacing: dim(9)) {
                        Image(nsImage: ledger.icon(for: c)).resizable().frame(width: dim(18), height: dim(18))
                        VStack(alignment: .leading, spacing: dim(4)) {
                            HStack {
                                Text(c.title).font(dim.text(11.5)).lineLimit(1)
                                Spacer()
                                Text(EnergyShare.label(c.fraction))
                                    .font(dim.number(11, .semibold))
                                    .foregroundStyle(.primary)
                                    .help(c.watts < 1 ? String(format: "%.0f mW", c.watts * 1000) : String(format: "%.1f W", c.watts))
                            }
                            Meter(fraction: c.fraction, tint: Hue.accent, thickness: dim(3))
                        }
                    }
                    .contextMenu {
                        if c.bundleURL != nil { Button(Copy.text("\(c.title) beenden", "Quit \(c.title)")) { ledger.requestQuit(c) } }
                    }
                }
            }
        }
    }
}

// MARK: - Dock

private struct DockBar: View {
    var dismiss: () -> Void
    @Environment(\.dim) private var dim
    @State private var working = false
    private let telemetry = Telemetry.shared

    var body: some View {
        let eco = telemetry.now.lowPower
        HStack(spacing: dim(8)) {
            Button {
                working = true
                EcoMode.set(!eco) { _ in working = false; telemetry.pull() }
            } label: {
                Label(eco ? Copy.text("Energiesparen an", "Low Power On") : Copy.text("Energiesparen", "Low Power Mode"),
                      systemImage: eco ? "leaf.fill" : "leaf")
                    .font(dim.text(10.5, .medium))
                    .foregroundStyle(eco ? Hue.accent : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(working)
            Spacer()
            Button {
                dismiss()
                Shortcuts.batteryPane()
            } label: {
                Label(Copy.text("Batterie", "Battery"), systemImage: "battery.100percent")
                    .font(dim.text(10.5, .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, dim(4))
        .padding(.top, dim(2))
    }
}
