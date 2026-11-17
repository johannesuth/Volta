import Foundation
import Observation
import Carbon.HIToolbox
import VoltaLanguageCore

// MARK: - Option types

enum Look: String, Codable, CaseIterable, Identifiable {
    case night, day, auto
    var id: Self { self }
    var title: String { ["night": Copy.text("Nacht", "Dark"), "day": Copy.text("Tag", "Light"), "auto": Copy.text("Automatisch", "Automatic")][rawValue]! }
}

enum GlyphStyle: String, Codable, CaseIterable, Identifiable {
    case cell, ring, cellPercent, digits, clock, bare
    var id: Self { self }
    var title: String {
        switch self {
        case .cell: Copy.text("Akkusymbol mit Ladestand", "Battery with level")
        case .ring: Copy.text("Ring", "Ring")
        case .cellPercent: Copy.text("Akkusymbol und Prozentangabe", "Battery + percent")
        case .digits: Copy.text("Nur Zahl", "Number only")
        case .clock: Copy.text("Restzeit und Ladestand", "Time remaining + level")
        case .bare: Copy.text("Nur Akkusymbol", "Battery only")
        }
    }
}

enum GlyphTint: String, Codable, CaseIterable, Identifiable {
    case status, blue, green, teal, violet, amber, rose, monochrome
    var id: Self { self }

    var title: String {
        switch self {
        case .status: Copy.text("Automatisch nach Akkustatus", "Automatic by battery status")
        case .blue: Copy.text("Blau", "Blue")
        case .green: Copy.text("Grün", "Green")
        case .teal: Copy.text("Türkis", "Teal")
        case .violet: Copy.text("Violett", "Violet")
        case .amber: Copy.text("Bernstein", "Amber")
        case .rose: Copy.text("Rosé", "Rose")
        case .monochrome: Copy.text("Einfarbig", "Monochrome")
        }
    }

    static func legacyValue(tinted: Bool?) -> GlyphTint {
        tinted == false ? .monochrome : .blue
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

struct TileExpansion: Equatable {
    private(set) var expandedTile: TileKind?

    init(expandedTile: TileKind? = nil) {
        self.expandedTile = expandedTile
    }

    /// The compact power-flow section opens with the dashboard; larger sections wait for a click.
    static func opening(shown: [TileKind]) -> TileExpansion {
        TileExpansion(expandedTile: shown.contains(.balance) ? .balance : nil)
    }

    func contains(_ tile: TileKind) -> Bool { expandedTile == tile }

    mutating func toggle(_ tile: TileKind) {
        expandedTile = expandedTile == tile ? nil : tile
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
    var title: String { ["family": Copy.text("Nach Gerätetyp", "By device type"), "name": Copy.text("Alphabetisch", "Alphabetically"), "emptiest": Copy.text("Niedrigster Ladestand zuerst", "Lowest charge first")][rawValue]! }
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

enum AuraStrength: String, Codable, CaseIterable, Identifiable {
    case faint, medium, vivid
    var id: Self { self }
    var title: String { ["faint": Copy.text("Zart", "Subtle"), "medium": Copy.text("Mittel", "Medium"), "vivid": Copy.text("Intensiv", "Strong")][rawValue]! }
    var gain: Double { ["faint": 0.55, "medium": 1.0, "vivid": 1.6][rawValue]! }
}

enum CardPlacement: String, Codable, CaseIterable, Identifiable {
    case smart, upper, middle, lowerRight
    var id: Self { self }
    var title: String { ["smart": Copy.text("Automatisch", "Smart"), "upper": Copy.text("Oben", "Top"), "middle": Copy.text("Mitte", "Center"), "lowerRight": Copy.text("Unten rechts", "Bottom right")][rawValue]! }
}

/// How a trigger shows up on screen.
enum Presentation: String, Codable, CaseIterable, Identifiable {
    case aura, card, both, banner
    var id: Self { self }
    var title: String { ["aura": Copy.text("Leuchtrahmen", "Edge glow"), "card": Copy.text("Hinweiskarte", "Notification card"), "both": Copy.text("Rahmen + Karte", "Glow + card"), "banner": Copy.text("Mitteilungszentrale", "Notification Center")][rawValue]! }
    var wantsAura: Bool { self == .aura || self == .both }
    var wantsCard: Bool { self == .card || self == .both }
}

/// A user rule: fire when the level crosses `level` going `down` (draining) or `up` (charging).
struct Trigger: Codable, Hashable, Identifiable {
    enum Direction: String, Codable, CaseIterable { case down, up }
    var id = UUID()
    var direction: Direction
    var level: Int
    var presentation: Presentation
    var tone: String
    var lingers = false
    var active = true

    static let starterSet: [Trigger] = [
        Trigger(direction: .down, level: 25, presentation: .aura, tone: "Tink"),
        Trigger(direction: .down, level: 12, presentation: .both, tone: "Funk", lingers: true),
        Trigger(direction: .down, level: 4, presentation: .both, tone: "Basso", lingers: true),
        Trigger(direction: .up, level: 85, presentation: .card, tone: "Ping"),
    ]
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
    var glyphTint: GlyphTint = .blue
    var glyphWatts = false
    var glyphQuietWhenFull = false
    var pinned: [String] = []

    // Dropdown
    var stickyDropdown = false
    var tiles: [TileKind] = TileKind.allCases
    static let optionalTiles: [TileKind] = [.balance, .trend, .vitals, .gadgets, .apps]
    static let defaultHiddenTiles: [TileKind] = [.vitals, .gadgets, .apps]
    var hiddenTiles: [TileKind] = Config.defaultHiddenTiles

    /// Version 2.1.3 hid every optional section by default; that untouched state moves to the newer,
    /// slightly richer default. Any other user choice is kept.
    static func migratedHiddenTiles(_ stored: [TileKind]) -> [TileKind] {
        stored.isEmpty || Set(stored) == Set(optionalTiles) ? defaultHiddenTiles : stored
    }
    var chartSpan: ChartSpan = .day
    var appRows = 3
    var gadgetOrder: GadgetOrder = .family
    var look: Look = .night
    var accent: Accent = .blue
    var vivid: Double = 0.35
    var panelTint: Double = 0.35
    var fahrenheit = false
    var showDecimals = true

    // System
    var shortcut = KeyCombo.standard
    var shortcutOn = true
    var pollSeconds: Double = 20
    var scanSeconds: Double = 45

    // Alerts
    var triggers: [Trigger] = Trigger.starterSet
    var aura: AuraStrength = .faint
    var cardPlacement: CardPlacement = .smart
    var cardSeconds: Double = 8
    var volume: Double = 0.8
    var quiet = QuietWindow()
    var gadgetFloor = 15
    var plugTone = true
    var bannerAlso = false
    var cooldownMinutes: Double = 10

    // Gadgets
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
        if storedObject["appRows"] as? Int == 5 {
            cfg.appRows = 3
        }
        cfg.appRows = min(max(cfg.appRows, 3), 6)
        if let vivid = storedObject["vivid"] as? Double, abs(vivid - 0.6) < 0.001 {
            cfg.vivid = 0.35
        }
        for index in cfg.triggers.indices where ["Stumm", "Silent"].contains(cfg.triggers[index].tone) {
            cfg.triggers[index].tone = Chime.silent
        }
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
