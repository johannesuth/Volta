// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import Foundation
import Observation

enum GadgetFamily: String, Codable, CaseIterable {
    case buds, overEar, speaker, mouse, keyboard, trackpad, controller, phone, watch, pen, misc

    var sfSymbol: String {
        switch self {
        case .buds: "earbuds"
        case .overEar: "headphones.over.ear"
        case .speaker: "hifispeaker.fill"
        case .mouse: "computermouse.fill"
        case .keyboard: "keyboard.fill"
        case .trackpad: "rectangle.and.hand.point.up.left.fill"
        case .controller: "gamecontroller.fill"
        case .phone: "iphone.gen3"
        case .watch: "applewatch.side.right"
        case .pen: "pencil.tip"
        case .misc: "wave.3.right"
        }
    }

    var rank: Int { Self.allCases.firstIndex(of: self) ?? 99 }

    /// Classifies from the profiler's minor type first, then from the product name.
    static func infer(minorType: String?, name: String) -> GadgetFamily {
        let probe = ((minorType ?? "") + " " + name).lowercased()
        let table: [(String, GadgetFamily)] = [
            ("airpods max", .overEar), ("headphones", .overEar), ("kopfhörer", .overEar),
            ("airpods", .buds), ("buds", .buds), ("beats fit", .buds), ("powerbeats", .buds), ("headset", .buds),
            ("speaker", .speaker), ("lautsprecher", .speaker),
            ("trackpad", .trackpad), ("mouse", .mouse), ("maus", .mouse),
            ("keyboard", .keyboard), ("tastatur", .keyboard),
            ("gamepad", .controller), ("controller", .controller), ("dualsense", .controller),
            ("phone", .phone), ("watch", .watch), ("pencil", .pen), ("stylus", .pen),
        ]
        return table.first { probe.contains($0.0) }?.1 ?? .misc
    }
}

struct Gadget: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var family: GadgetFamily
    var single: Int?
    var leftBud: Int?
    var rightBud: Int?
    var caseLevel: Int?
    var connected: Bool
    var lastSeen: Date

    var lowest: Int? { [single, leftBud, rightBud].compactMap { $0 }.min() }
    var isPair: Bool { leftBud != nil || rightBud != nil }
}

/// Reads accessory batteries from `system_profiler SPBluetoothDataType -json`.
/// Needs no Bluetooth permission and covers AirPods, Beats, Magic accessories and most HID gear.
actor GadgetScanner {
    func scan() async -> [Gadget] {
        guard let json = await Self.runProfiler() else { return [] }
        let now = Date.now
        var found: [Gadget] = []
        for controller in json["SPBluetoothDataType"] as? [[String: Any]] ?? [] {
            for (section, connected) in [("device_connected", true), ("device_not_connected", false)] {
                for wrapper in controller[section] as? [[String: Any]] ?? [] {
                    for (name, value) in wrapper {
                        guard let info = value as? [String: Any] else { continue }
                        let levels = (Self.percent(info["device_batteryLevelMain"]),
                                      Self.percent(info["device_batteryLevelLeft"]),
                                      Self.percent(info["device_batteryLevelRight"]),
                                      Self.percent(info["device_batteryLevelCase"]))
                        guard levels.0 != nil || levels.1 != nil || levels.2 != nil || levels.3 != nil else { continue }
                        let address = (info["device_address"] as? String ?? name).uppercased()
                        found.append(Gadget(id: address, name: name,
                                            family: .infer(minorType: info["device_minorType"] as? String, name: name),
                                            single: levels.0, leftBud: levels.1, rightBud: levels.2, caseLevel: levels.3,
                                            connected: connected, lastSeen: now))
                    }
                }
            }
        }
        return found
    }

    private static func percent(_ any: Any?) -> Int? {
        guard let text = any as? String else { return (any as? NSNumber)?.intValue }
        let digits = text.filter(\.isNumber)
        guard let v = Int(digits), (0...100).contains(v) else { return nil }
        return v
    }

    private static func runProfiler() async -> [String: Any]? {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .utility).async {
                let proc = Process()
                proc.executableURL = URL(filePath: "/usr/sbin/system_profiler")
                proc.arguments = ["SPBluetoothDataType", "-json"]
                let out = Pipe()
                proc.standardOutput = out
                proc.standardError = FileHandle.nullDevice
                guard (try? proc.run()) != nil else { cont.resume(returning: nil); return }
                let data = out.fileHandleForReading.readDataToEndOfFile()   // drains until the tool exits
                proc.waitUntilExit()
                cont.resume(returning: (try? JSONSerialization.jsonObject(with: data)) as? [String: Any])
            }
        }
    }
}

/// Observable list of accessories; remembers devices it has seen in `gadgets.json`.
@Observable @MainActor
final class GadgetHub {
    static let shared = GadgetHub()

    private(set) var all: [Gadget] = []

    @ObservationIgnored private let scanner = GadgetScanner()
    @ObservationIgnored private var memory: [String: Gadget] = [:]
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var boosted = 0
    @ObservationIgnored private let file = ConfigStore.shared.folder.appending(path: "gadgets.json")

    private init() {
        if let data = try? Data(contentsOf: file), let saved = try? JSONDecoder().decode([Gadget].self, from: data) {
            memory = Dictionary(saved.map { g in var g = g; g.connected = false; return (g.id, g) }, uniquingKeysWith: { a, _ in a })
            all = arrange(Array(memory.values))
        }
        relaunchLoop()
    }

    func boost() -> Telemetry.Lease {
        boosted += 1
        relaunchLoop()
        return Telemetry.Lease { [weak self] in
            DispatchQueue.main.async { MainActor.assumeIsolated {
                self?.boosted -= 1
                self?.relaunchLoop()
            } }
        }
    }

    /// Seconds between scans while nothing accessory-related is on screen. Accessory batteries drain slowly,
    /// so this is plenty for low-battery alerts; each scan starts a `system_profiler` process.
    nonisolated static let backgroundInterval: Double = 120
    /// Seconds between scans while the Accessories section is visible.
    nonisolated static let liveInterval: Double = 10

    /// Background scans only run if something uses them: the Accessories section, a pinned accessory
    /// in the menu bar, or the accessory low-battery alert.
    static func needsBackgroundScan(_ c: Config) -> Bool {
        let sectionShown = c.tiles.contains(.gadgets) && !c.hiddenTiles.contains(.gadgets)
        return sectionShown || !c.pinned.isEmpty || c.gadgetFloor > 0
    }

    private func relaunchLoop() {
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                let live = (self?.boosted ?? 0) > 0
                if live || Self.needsBackgroundScan(ConfigStore.shared.c) { await self?.rescan() }
                try? await Task.sleep(for: .seconds(live ? Self.liveInterval : Self.backgroundInterval))
            }
        }
    }

    func rescan() async {
        let fresh = await scanner.scan()
        let liveIDs = Set(fresh.map(\.id))
        for var g in fresh {
            // AirPods report the case only while it is open; keep the last known value.
            if g.caseLevel == nil { g.caseLevel = memory[g.id]?.caseLevel }
            if !g.connected, let old = memory[g.id] { g.lastSeen = old.lastSeen }
            memory[g.id] = g
        }
        for (id, var g) in memory where !liveIDs.contains(id) {
            g.connected = false
            memory[id] = g
        }
        all = arrange(Array(memory.values))
        if let data = try? JSONEncoder().encode(Array(memory.values)) { try? data.write(to: file, options: .atomic) }
        NotificationCenter.default.post(name: .gadgetsScanned, object: all)
    }

    func forget(_ id: String) {
        memory[id] = nil
        all.removeAll { $0.id == id }
        if let data = try? JSONEncoder().encode(Array(memory.values)) { try? data.write(to: file, options: .atomic) }
    }

    func arrange(_ list: [Gadget]) -> [Gadget] {
        let order = ConfigStore.shared.c.gadgetOrder
        return list.sorted { a, b in
            if a.connected != b.connected { return a.connected }
            switch order {
            case .name: return a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .emptiest: return (a.lowest ?? 999) < (b.lowest ?? 999)
            case .family: return a.family.rank == b.family.rank
                ? a.name.localizedStandardCompare(b.name) == .orderedAscending
                : a.family.rank < b.family.rank
            }
        }
    }

    var visible: [Gadget] {
        let hidden = Set(ConfigStore.shared.c.hiddenGadgets)
        return arrange(all).filter { !hidden.contains($0.id) }
    }
}
