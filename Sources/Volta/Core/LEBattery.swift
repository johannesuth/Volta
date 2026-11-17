// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import CoreBluetooth
import Foundation

/// Battery levels that devices publish over Bluetooth Low Energy with the standard Battery Service.
/// iPhones and iPads share their level this way with the Mac they are paired with; `system_profiler`
/// does not report it.
enum LEBattery {
    struct Reading: Equatable {
        let id: UUID
        let name: String
        let level: Int
    }

    static let service = CBUUID(string: "180F")        // Battery Service
    static let characteristic = CBUUID(string: "2A19") // Battery Level, one byte 0…100

    static func level(from data: Data) -> Int? {
        guard let byte = data.first, byte <= 100 else { return nil }
        return Int(byte)
    }
}

/// Reads the Battery Service of devices that are already connected to this Mac. It never scans or
/// advertises: it attaches to existing links and subscribes, so iOS pushes a new value when it changes.
/// All work happens on the main queue.
final class LEBatteryReader: NSObject, @unchecked Sendable {
    private var central: CBCentralManager?
    private var peripherals: [UUID: CBPeripheral] = [:]
    private(set) var readings: [UUID: LEBattery.Reading] = [:]
    var onChange: () -> Void = {}

    /// True when the user declined Bluetooth access for Volta.
    var denied: Bool { CBManager.authorization == .denied || CBManager.authorization == .restricted }

    /// Starts on first use (macOS asks for Bluetooth access then) and looks for newly connected devices.
    func start() {
        guard central != nil else {
            central = CBCentralManager(delegate: self, queue: .main,
                                       options: [CBCentralManagerOptionShowPowerAlertKey: false])
            return
        }
        refresh()
    }

    func stop() {
        guard let central else { return }
        for peripheral in peripherals.values { central.cancelPeripheralConnection(peripheral) }
        peripherals = [:]
        let hadReadings = !readings.isEmpty
        readings = [:]
        self.central = nil
        if hadReadings { onChange() }
    }

    private func refresh() {
        guard let central, central.state == .poweredOn else { return }
        let connected = central.retrieveConnectedPeripherals(withServices: [LEBattery.service])
        let present = Set(connected.map(\.identifier))
        var changed = false
        for (id, peripheral) in peripherals where !present.contains(id) {
            central.cancelPeripheralConnection(peripheral)
            peripherals[id] = nil
            if readings.removeValue(forKey: id) != nil { changed = true }
        }
        for peripheral in connected where peripherals[peripheral.identifier] == nil {
            peripherals[peripheral.identifier] = peripheral
            peripheral.delegate = self
            central.connect(peripheral)
        }
        if changed { onChange() }
    }

    private func record(_ peripheral: CBPeripheral, data: Data?) {
        guard let data, let level = LEBattery.level(from: data) else { return }
        let name = peripheral.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let reading = LEBattery.Reading(id: peripheral.identifier,
                                        name: name?.isEmpty == false ? name! : Copy.text("Gerät", "Device"),
                                        level: level)
        guard readings[peripheral.identifier] != reading else { return }
        readings[peripheral.identifier] = reading
        onChange()
    }
}

extension LEBatteryReader: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            refresh()
        } else if !readings.isEmpty {
            peripherals = [:]
            readings = [:]
            onChange()
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([LEBattery.service])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        peripherals[peripheral.identifier] = nil
        if readings.removeValue(forKey: peripheral.identifier) != nil { onChange() }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        peripherals[peripheral.identifier] = nil
    }
}

extension LEBatteryReader: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services ?? [] where service.uuid == LEBattery.service {
            peripheral.discoverCharacteristics([LEBattery.characteristic], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics ?? [] where characteristic.uuid == LEBattery.characteristic {
            peripheral.readValue(for: characteristic)
            if characteristic.properties.contains(.notify) { peripheral.setNotifyValue(true, for: characteristic) }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, characteristic.uuid == LEBattery.characteristic else { return }
        record(peripheral, data: characteristic.value)
    }
}
