// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import XCTest
@testable import Volta

final class GlyphColorTests: XCTestCase {
    func testLevelBandsSwitchAtFiftyAndTwentyPercent() {
        XCTAssertEqual(LevelBand(level: 100), .high)
        XCTAssertEqual(LevelBand(level: 51), .high)
        XCTAssertEqual(LevelBand(level: 50), .medium)
        XCTAssertEqual(LevelBand(level: 21), .medium)
        XCTAssertEqual(LevelBand(level: 20), .low)
        XCTAssertEqual(LevelBand(level: 0), .low)
    }

    func testFreshConfigurationColorsTheIconByChargeLevel() {
        XCTAssertEqual(Config().glyphTint, .level)
    }

    func testSettingsOfferOnlyThreeSimpleIconColorChoices() {
        XCTAssertEqual(GlyphTint.allCases, [.level, .accent, .monochrome])
    }

    func testEarlierColorChoicesStillDecode() throws {
        func decode(_ raw: String) throws -> GlyphTint {
            try JSONDecoder().decode(GlyphTint.self, from: Data("\"\(raw)\"".utf8))
        }
        XCTAssertEqual(try decode("status"), .level)
        XCTAssertEqual(try decode("blue"), .accent)
        XCTAssertEqual(try decode("rose"), .accent)
        XCTAssertEqual(try decode("monochrome"), .monochrome)
        XCTAssertEqual(try decode("something-new"), .level)
    }

    func testLegacyMonochromeSettingMigrates() {
        XCTAssertEqual(GlyphTint.legacyValue(tinted: false), .monochrome)
        XCTAssertEqual(GlyphTint.legacyValue(tinted: true), .accent)
        XCTAssertEqual(GlyphTint.legacyValue(tinted: nil), .level)
    }
}
