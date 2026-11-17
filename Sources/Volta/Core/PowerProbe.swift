// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import Foundation
import IOKit

struct ChargerInfo: Equatable {
    var ratedWatts: Int?
    var label: String?
    var volts: Double?
    var amps: Double?
    var wireless = false
}

enum FlowMode: Equatable {
    case draining      // running from the pack
    case filling       // adapter charges the pack
    case resting       // on adapter, pack neither filling nor draining
    case topped        // on adapter at 100 %
    case deficit       // on adapter but the pack still has to help
    case mainsOnly     // desktop Mac, no pack
}

/// Immutable picture of the power system at one instant.
struct PowerSnapshot: Equatable {
    var taken = Date.distantPast
    var hasPack = false
    var level = 0
    var onMains = false
    var filling = false
    var complete = false
    var minutesToEmpty: Int?
    var minutesToFull: Int?
    var cycles = 0
    var designMAh = 0
    var fullMAh = 0
    var nominalMAh = 0
    var storedMAh = 0
    var volts = 0.0
    var milliamps = 0.0
    var packWatts = 0.0      // positive = into the pack
    var mainsWatts = 0.0
    var systemWatts = 0.0
    var celsius: Double?
    var charger: ChargerInfo?
    var serial = ""
    var lowPower = false
    var deficit = false

    var mode: FlowMode {
        if !hasPack { return .mainsOnly }
        if deficit { return .deficit }
        if filling { return .filling }
        if onMains { return (complete || level >= 100) ? .topped : .resting }
        return .draining
    }

    /// Full-charge capacity against the factory design value.
    var wear: Double? {
        guard designMAh > 0, fullMAh > 0 else { return nil }
        return min(100, Double(fullMAh) / Double(designMAh) * 100)
    }

    /// The more forgiving "nominal" figure that the system UI is closer to.
    var nominalWear: Double? {
        guard designMAh > 0, nominalMAh > 0 else { return nil }
        return min(100, Double(nominalMAh) / Double(designMAh) * 100)
    }
}

/// Reads the smart-battery registry node key by key.
enum PowerProbe {
    private struct Node {
        let entry: io_registry_entry_t
        subscript(_ key: String) -> Any? {
            IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
        }
        func int(_ key: String) -> Int? { (self[key] as? NSNumber).map { Int(truncatingIfNeeded: $0.int64Value) } }
        func flag(_ key: String) -> Bool? { (self[key] as? NSNumber)?.boolValue }
        func dict(_ key: String) -> [String: Any] { self[key] as? [String: Any] ?? [:] }
    }

    static func batteryEntry() -> io_registry_entry_t {
        IOServiceGetMatchingService(kIOMainPortDefault, IOServiceNameMatching("AppleSmartBattery"))
    }

    static func sample(previous: PowerSnapshot?) -> PowerSnapshot {
        var s = PowerSnapshot()
        s.taken = .now
        s.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        let entry = batteryEntry()
        guard entry != 0 else { return s }
        defer { IOObjectRelease(entry) }
        let n = Node(entry: entry)
        guard n.flag("BatteryInstalled") ?? true else { return s }

        s.hasPack = true
        let telemetry = n.dict("PowerTelemetryData")
        let packData = n.dict("BatteryData")
        func pick(_ key: String) -> Int? { n.int(key) ?? (packData[key] as? NSNumber)?.intValue }

        let current = n.int("CurrentCapacity") ?? 0
        let maximum = max(1, n.int("MaxCapacity") ?? 100)
        s.level = min(100, Int((Double(current) / Double(maximum) * 100).rounded()))
        s.onMains = n.flag("ExternalConnected") ?? false
        s.filling = n.flag("IsCharging") ?? false
        s.complete = n.flag("FullyCharged") ?? false
        s.cycles = n.int("CycleCount") ?? 0
        s.designMAh = pick("DesignCapacity") ?? 0
        s.fullMAh = pick("AppleRawMaxCapacity") ?? pick("FullChargeCapacity") ?? 0
        s.nominalMAh = pick("NominalChargeCapacity") ?? 0
        s.storedMAh = pick("AppleRawCurrentCapacity") ?? 0
        s.volts = Double(n.int("Voltage") ?? 0) / 1000
        s.milliamps = Double(n.int("InstantAmperage") ?? n.int("Amperage") ?? 0)
        s.serial = n["Serial"] as? String ?? ""

        let tte = n.int("AvgTimeToEmpty") ?? n.int("TimeRemaining") ?? 65535
        let ttf = n.int("AvgTimeToFull") ?? 65535
        s.minutesToEmpty = (!s.onMains && tte > 0 && tte < 6000) ? tte : nil
        s.minutesToFull = (s.filling && ttf > 0 && ttf < 6000) ? ttf : nil

        let mw = { (key: String) -> Double? in (telemetry[key] as? NSNumber).map { $0.doubleValue / 1000 } }
        s.packWatts = mw("BatteryPower") ?? (packData["BatteryPower"] as? NSNumber).map { $0.doubleValue / 1000 }
            ?? s.volts * s.milliamps / 1000
        s.mainsWatts = s.onMains ? (mw("SystemPowerIn") ?? 0) : 0
        s.systemWatts = mw("SystemLoad").flatMap { $0 > 0 ? $0 : nil }
            ?? SensorBus.shared.systemWatts
            ?? max(0, s.mainsWatts - s.packWatts)

        if let centi = n.int("Temperature") ?? n.int("VirtualTemperature"), centi > 0 {
            s.celsius = Double(centi) / 100
        } else {
            s.celsius = SensorBus.shared.packCelsius ?? previous?.celsius
        }

        if s.onMains {
            let a = n.dict("AdapterDetails")
            var info = ChargerInfo()
            info.ratedWatts = (a["Watts"] as? NSNumber)?.intValue
            info.label = (a["Name"] as? String) ?? (a["Description"] as? String)
            info.volts = (a["AdapterVoltage"] as? NSNumber).map { $0.doubleValue / 1000 }
            info.amps = (a["Current"] as? NSNumber).map { $0.doubleValue / 1000 }
            info.wireless = (a["IsWireless"] as? NSNumber)?.boolValue ?? false
            s.charger = info
        }
        return s
    }
}

/// Fires `handler` whenever the battery driver broadcasts a general-interest message.
final class PackWatcher {
    private var port: IONotificationPortRef?
    private var notifier: io_object_t = 0
    private let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
        let entry = PowerProbe.batteryEntry()
        guard entry != 0 else { return }
        defer { IOObjectRelease(entry) }
        port = IONotificationPortCreate(kIOMainPortDefault)
        guard let port else { return }
        IONotificationPortSetDispatchQueue(port, .main)
        let me = Unmanaged.passUnretained(self).toOpaque()
        IOServiceAddInterestNotification(port, entry, kIOGeneralInterest, { ctx, _, _, _ in
            guard let ctx else { return }
            Unmanaged<PackWatcher>.fromOpaque(ctx).takeUnretainedValue().handler()
        }, me, &notifier)
    }

    deinit {
        if notifier != 0 { IOObjectRelease(notifier) }
        if let port { IONotificationPortDestroy(port) }
    }
}
