// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import Foundation
import XCTest
@testable import Volta

/// iPhones and iPads report their battery to a paired Mac over Bluetooth Low Energy (Battery Service),
/// which `system_profiler` does not show.
final class BluetoothBatteryTests: XCTestCase {
    func testBatteryLevelIsTheFirstByteAndMustBeAPercentage() {
        XCTAssertEqual(LEBattery.level(from: Data([82])), 82)
        XCTAssertEqual(LEBattery.level(from: Data([100, 7])), 100)
        XCTAssertNil(LEBattery.level(from: Data()))
        XCTAssertNil(LEBattery.level(from: Data([101])), "values above 100 are not a percentage")
    }

    func testPhoneNamesAreRecognised() {
        XCTAssertEqual(GadgetFamily.infer(minorType: nil, name: "iPhone 18 Pro Johannes🚦"), .phone)
        XCTAssertEqual(GadgetFamily.infer(minorType: nil, name: "iPad von Anna"), .tablet)
    }

    func testBluetoothReadingsJoinTheProfilerList() {
        let seen = Date(timeIntervalSince1970: 1_800_000_000)
        let mouse = Gadget(id: "AA:BB", name: "Magic Mouse", family: .mouse, single: 64, leftBud: nil, rightBud: nil,
                           caseLevel: nil, connected: true, lastSeen: seen)
        let readings = [
            LEBattery.Reading(id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!, name: "iPhone 18 Pro Johannes🚦", level: 82),
            // The same mouse also offers the Battery Service; the profiler entry wins.
            LEBattery.Reading(id: UUID(uuidString: "66666666-7777-8888-9999-000000000000")!, name: "magic mouse ", level: 63),
        ]
        let merged = GadgetHub.merge(profiler: [mouse], bluetooth: readings, now: seen)
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged.first { $0.family == .mouse }?.single, 64)
        let phone = merged.first { $0.family == .phone }
        XCTAssertEqual(phone?.single, 82)
        XCTAssertEqual(phone?.name, "iPhone 18 Pro Johannes🚦")
        XCTAssertEqual(phone?.id, "le:11111111-2222-3333-4444-555555555555")
        XCTAssertEqual(phone?.connected, true)
    }
}
