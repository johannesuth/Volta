import Foundation
import Observation
import Carbon.HIToolbox
import VoltaLanguageCore

// MARK: - Option types

enum Look: String, Codable, CaseIterable, Identifiable {
    case auto, day, night
    var id: Self { self }
    var title: String {
        switch self {
        case .auto: Copy.text("Automatisch", "Automatic")
        case .day: Copy.text("Hell", "Light")
        case .night: Copy.text("Dunkel", "Dark")
        }
    }
}

enum GlyphStyle: String, Codable, CaseIterable, Identifiable {
    case cell, ring, cellPercent, digits, clock, bare
    var id: Self { self }
    /// The styles offered in Settings; the others remain readable for older configurations.
    static let choices: [GlyphStyle] = [.cell, .cellPercent, .digits, .bare]
    var title: String {
        switch self {
        case .cell: Copy.text("Akku mit Zahl", "Battery with level")
        case .ring: Copy.text("Ring", "Ring")
        case .cellPercent: Copy.text("Prozent + Akku", "Percent + battery")
        case .digits: Copy.text("Nur Prozent", "Percent only")
        case .clock: Copy.text("Restzeit und Ladestand", "Time remaining + level")
        case .bare: Copy.text("Nur Akku", "Battery only")
        }
    }
}

/// How the menu-bar battery is coloured.
enum GlyphTint: String, Codable, CaseIterable, Identifiable {
    case level, accent, monochrome
    var id: Self { self }

    var title: String {
        switch self {
        case .level: Copy.text("Nach Ladestand", "By charge level")
        case .accent: Copy.text("Akzentfarbe", "Accent color")
        case .monochrome: Copy.text("Einfarbig", "Monochrome")
        }
    }

    /// Older versions stored individual colours; they map onto the current, smaller set.
    init(from decoder: Decoder) throws {
        switch try decoder.singleValueContainer().decode(String.self) {
        case "accent", "blue", "green", "teal", "violet", "amber", "rose": self = .accent
        case "monochrome": self = .monochrome
        default: self = .level
        }
    }

    static func legacyValue(tinted: Bool?) -> GlyphTint {
        switch tinted {
        case false?: .monochrome
        case true?: .accent
        case nil: .level
        }
    }
}

enum TileKind: String, Codable, CaseIterable, Identifiable {
    case charge, balance, trend, vitals, gadgets, apps
    var id: Self { self }
    var title: String {
        switch self {
        case .charge: Copy.text("Ladung", "Charge")
        case .balance: Copy.text("Energiefluss", "Power flow")
        case .trend: Copy.text("Verlauf", "History")
        case .vitals: Copy.text("Akkuzustand", "Battery health")
        case .gadgets: Copy.text("Zubehör", "Accessories")
        case .apps: Copy.text("Energieverbrauch", "App energy use")
        }
    }
    var icon: String {
        switch self {
        case .charge: "drop.fill"
        case .balance: "arrow.left.arrow.right"
        case .trend: "waveform.path.ecg"
        case .vitals: "cross.case.fill"
        case .gadgets: "headphones"
        case .apps: "bolt.badge.clock.fill"
        }
    }
}

/// Which dashboard sections are unfolded. Any number can be open; the order records when each
/// was opened so the earliest one can fold away if the panel would not fit on screen.
struct TileExpansion: Codable, Equatable {
    private(set) var openTiles: [TileKind]

    init(openTiles: [TileKind] = []) {
        self.openTiles = openTiles
    }

    static let standard = TileExpansion(openTiles: [.vitals, .apps])

    func contains(_ tile: TileKind) -> Bool { openTiles.contains(tile) }

    mutating func toggle(_ tile: TileKind) {
        if contains(tile) { openTiles.removeAll { $0 == tile } } else { openTiles.append(tile) }
    }

    /// Folds the section that has been open longest. Returns `false` when nothing is open.
    @discardableResult
    mutating func collapseOldest() -> Bool {
        guard !openTiles.isEmpty else { return false }
        openTiles.removeFirst()
        return true
    }
}

enum ChartSpan: String, Codable, CaseIterable, Identifiable {
    case sixHours, day, week
    var id: Self { self }
    var title: String { ["sixHours": Copy.text("6 Std", "6 hours"), "day": Copy.text("1 Tag", "1 day"), "week": Copy.text("1 Woche", "1 week")][rawValue]! }
    var interval: TimeInterval { ["sixHours": 21_600.0, "day": 86_400.0, "week": 604_800.0][rawValue]! }
}

enum GadgetOrder: String, Codable, CaseIterable, Identifiable {
    case family, name, emptiest
    var id: Self { self }
}

/// The one accent colour of the otherwise neutral interface.
enum Accent: String, Codable, CaseIterable, Identifiable {
    case graphite, system, blue, teal, mint, indigo, amber, rose
    var id: Self { self }
    var title: String {
        ["graphite": Copy.text("Graphit", "Graphite"), "system": Copy.text("Systemfarbe", "System color"), "blue": Copy.text("Blau", "Blue"), "teal": Copy.text("Petrol", "Teal"), "mint": Copy.text("Minzgrün", "Mint"),
         "indigo": "Indigo", "amber": Copy.text("Bernstein", "Amber"), "rose": Copy.text("Rosé", "Rose")][rawValue]!
    }
}

enum CardPlacement: String, Codable, CaseIterable {
    case smart, upper, middle, lowerRight
}

/// How an alert shows up on screen.
enum Presentation: String, Codable, CaseIterable, Identifiable {
    case aura, card, both, banner
    var id: Self { self }
    var title: String {
        switch self {
        case .aura: Copy.text("Leuchtrand", "Edge glow")
        case .card: Copy.text("Karte", "Card")
        case .both: Copy.text("Karte + Leuchtrand", "Card + glow")
        case .banner: Copy.text("Mitteilung", "Notification")
        }
    }
    var wantsAura: Bool { self == .aura || self == .both }
    var wantsCard: Bool { self == .card || self == .both }
}

/// A rule: fire when the level crosses `level` going `down` (draining) or `up` (charging).
struct Trigger: Codable, Hashable, Identifiable {
    enum Direction: String, Codable, CaseIterable { case down, up }
    var id = UUID()
    var direction: Direction
    var level: Int
    var presentation: Presentation
    var tone: String
    var lingers = false
    var active = true
}

/// The two everyday battery alerts, edited in Settings and turned into rules for `Sentinel`.
struct AlertPlan: Codable, Equatable {
    var lowOn = true
    var lowLevel = 20
    var fullOn = true
    var fullLevel = 100
    var style: Presentation = .card
    var tone = "Glass"

    static let lowLevels = [10, 15, 20, 25, 30]
    static let fullLevels = [80, 90, 100]
    static let styles: [Presentation] = [.card, .both, .banner]

    private static let lowID = UUID(uuidString: "6C1F4E0A-2B7D-4C59-9E21-0B5D7A3F8E11")!
    private static let fullID = UUID(uuidString: "C3A9D2B4-7E15-4F80-A6C2-5D1E9B7F4A22")!

    var triggers: [Trigger] {
        var rules: [Trigger] = []
        if lowOn {
            rules.append(Trigger(id: Self.lowID, direction: .down, level: lowLevel, presentation: style, tone: tone,
                                 lingers: lowLevel <= 10))
        }
        if fullOn {
            rules.append(Trigger(id: Self.fullID, direction: .up, level: fullLevel, presentation: style, tone: tone))
        }
        return rules
    }

    /// Converts the rule list of version 2.1 and earlier. The untouched starter set becomes the new default.
    static func migrated(from old: [Trigger]) -> AlertPlan {
        if old.map({ "\($0.direction.rawValue)\($0.level)" }) == ["down25", "down12", "down4", "up85"] { return AlertPlan() }
        var plan = AlertPlan()
        let downs = old.filter { $0.direction == .down }
        if let low = downs.filter(\.active).max(by: { $0.level < $1.level }) ?? downs.max(by: { $0.level < $1.level }) {
            plan.lowLevel = low.level
            plan.lowOn = low.active
            plan.style = low.presentation == .aura ? .both : low.presentation
            plan.tone = ["Stumm", "Silent"].contains(low.tone) ? Chime.silent : low.tone
        } else {
            plan.lowOn = false
        }
        if let up = old.first(where: { $0.direction == .up }) {
            plan.fullLevel = up.level
            plan.fullOn = up.active
        } else {
            plan.fullOn = false
        }
        return plan
    }
}

struct KeyCombo: Codable, Hashable {
    var keyCode: UInt32
    var carbonFlags: UInt32
    var label: String
    static let standard = KeyCombo(keyCode: UInt32(kVK_ANSI_V), carbonFlags: UInt32(controlKey | optionKey), label: "⌃⌥V")
}

struct QuietWindow: Codable, Hashable {
    var enabled = false
    var fromHour = 22
    var toHour = 7
    func contains(_ date: Date = .now) -> Bool {
        guard enabled else { return false }
        let h = Calendar.current.component(.hour, from: date)
        return fromHour == toHour ? true
            : fromHour < toHour ? (fromHour..<toHour).contains(h) : (h >= fromHour || h < toHour)
    }
}

// MARK: - The whole configuration, persisted as one JSON document

struct Config: Codable, Equatable {
    // Menu bar
    var glyph: GlyphStyle = .cell
    var glyphTint: GlyphTint = .level
    var glyphWatts = false
    var glyphQuietWhenFull = false
    var pinned: [String] = []

    // Dashboard
    var stickyDropdown = false
    static let defaultTileOrder: [TileKind] = [.charge, .vitals, .apps, .trend, .gadgets, .balance]
    var tiles: [TileKind] = Config.defaultTileOrder
    static let optionalTiles: [TileKind] = [.balance, .trend, .vitals, .gadgets, .apps]
    /// Battery health, app energy use and history are shown by default; power flow is an advanced extra.
    static let defaultHiddenTiles: [TileKind] = [.balance, .gadgets]
    var hiddenTiles: [TileKind] = Config.defaultHiddenTiles
    var expansion = TileExpansion.standard
    /// mAh, voltage and current in the battery-health section.
    var showBatteryDetails = false
    var chartSpan: ChartSpan = .day
    var appRows = 3
    var gadgetOrder: GadgetOrder = .family

    // Appearance
    var look: Look = .auto
    var accent: Accent = .blue
    var fahrenheit = false

    // System
    var shortcut = KeyCombo.standard
    var shortcutOn = true
    var pollSeconds: Double = 20
    var scanSeconds: Double = 45

    // Alerts
    var alerts = AlertPlan()
    var volume: Double = 0.8
    var quiet = QuietWindow()
    var gadgetFloor = 20
    var plugTone = true

    // Accessories
    var hiddenGadgets: [String] = []

    // Data
    var keepDays = 90
    var onboarded = false
    var language: AppLanguage = .detected(from: Locale.current.identifier)
    var languageChosen = false

    func resetForSettings() -> Config {
        var fresh = Config()
        fresh.onboarded = onboarded
        fresh.language = language
        fresh.languageChosen = languageChosen
        fresh.pinned = pinned
        fresh.keepDays = keepDays
        return fresh
    }

    // MARK: Migration of earlier defaults (custom choices are always kept)

    static func migratedHiddenTiles(_ stored: [TileKind]) -> [TileKind] {
        let earlierDefaults: [Set<TileKind>] = [Set(optionalTiles), [.vitals, .gadgets, .apps], [.balance, .gadgets, .apps]]
        return stored.isEmpty || earlierDefaults.contains(Set(stored)) ? defaultHiddenTiles : stored
    }

    static func migratedTileOrder(_ stored: [TileKind]) -> [TileKind] {
        let earlierDefaults: [[TileKind]] = [TileKind.allCases, [.charge, .vitals, .trend, .balance, .gadgets, .apps]]
        return earlierDefaults.contains(stored) ? defaultTileOrder : stored
    }

    static func migratedExpansion(_ stored: TileExpansion) -> TileExpansion {
        stored == TileExpansion(openTiles: [.vitals]) ? .standard : stored
    }
}

/// Observable owner of `Config`. Writes are debounced into `config.json`; unknown or missing keys
/// fall back to defaults by merging the stored document over a freshly encoded default document.
@Observable
final class ConfigStore {
    static let shared = ConfigStore()

    var c: Config {
        didSet {
            guard c != oldValue else { return }
            scheduleWrite()
            NotificationCenter.default.post(name: .configChanged, object: nil)
        }
    }

    @ObservationIgnored private var pendingWrite: DispatchWorkItem?
    @ObservationIgnored let folder: URL

    private var file: URL { folder.appending(path: "config.json") }

    private init() {
        let folderName = AppProfile.supportFolderName(arguments: ProcessInfo.processInfo.arguments)
        folder = URL.applicationSupportDirectory.appending(path: folderName, directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        c = Self.read(from: folder.appending(path: "config.json"))
    }

    private static func read(from url: URL) -> Config {
        guard let stored = try? Data(contentsOf: url),
              let storedObject = try? JSONSerialization.jsonObject(with: stored) as? [String: Any],
              let defaultsData = try? JSONEncoder().encode(Config()),
              var merged = try? JSONSerialization.jsonObject(with: defaultsData) as? [String: Any]
        else { return Config() }
        merged.merge(storedObject) { _, new in new }
        guard let data = try? JSONSerialization.data(withJSONObject: merged),
              var cfg = try? JSONDecoder().decode(Config.self, from: data) else { return Config() }
        if storedObject["glyphTint"] == nil {
            cfg.glyphTint = GlyphTint.legacyValue(tinted: storedObject["glyphTinted"] as? Bool)
        }
        if storedObject["hiddenTiles"] != nil {
            cfg.hiddenTiles = Config.migratedHiddenTiles(cfg.hiddenTiles)
        }
        cfg.tiles = Config.migratedTileOrder(cfg.tiles)
        cfg.expansion = Config.migratedExpansion(cfg.expansion)
        if storedObject["alerts"] == nil, let raw = storedObject["triggers"],
           let rulesData = try? JSONSerialization.data(withJSONObject: raw),
           let rules = try? JSONDecoder().decode([Trigger].self, from: rulesData) {
            cfg.alerts = AlertPlan.migrated(from: rules)
        }
        cfg.appRows = min(max(cfg.appRows, 3), 6)
        return cfg
    }

    private func scheduleWrite() {
        pendingWrite?.cancel()
        let snapshot = c
        let target = file
        let job = DispatchWorkItem {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            try? enc.encode(snapshot).write(to: target, options: .atomic)
        }
        pendingWrite = job
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.35, execute: job)
    }

    func restoreDefaults() {
        c = c.resetForSettings()
    }

    // Convenience mutators used by several screens
    var shownTiles: [TileKind] { c.tiles.filter { !c.hiddenTiles.contains($0) } }

    func toggleTile(_ t: TileKind, on: Bool) {
        c.hiddenTiles.removeAll { $0 == t }
        if !on { c.hiddenTiles.append(t) }
    }

    func degrees(_ celsius: Double) -> String {
        c.fahrenheit ? "\(Int((celsius * 1.8 + 32).rounded())) °F" : String(format: "%.1f °C", celsius)
    }
}
