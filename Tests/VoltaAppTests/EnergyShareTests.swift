// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import XCTest
@testable import Volta

final class EnergyShareTests: XCTestCase {
    func testShareIsShownAsWholePercent() {
        XCTAssertEqual(EnergyShare.label(0.314), "31 %")
        XCTAssertEqual(EnergyShare.label(0.996), "100 %")
        XCTAssertEqual(EnergyShare.label(0.05), "5 %")
    }

    func testTinySharesReadAsBelowOnePercent() {
        XCTAssertEqual(EnergyShare.label(0.004), "< 1 %")
        XCTAssertEqual(EnergyShare.label(0), "< 1 %")
    }

    func testOutOfRangeValuesAreClamped() {
        XCTAssertEqual(EnergyShare.label(1.7), "100 %")
        XCTAssertEqual(EnergyShare.label(-0.2), "< 1 %")
        XCTAssertEqual(EnergyShare.label(.nan), "< 1 %")
    }
}
