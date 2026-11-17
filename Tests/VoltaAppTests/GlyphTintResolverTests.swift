import XCTest
@testable import Volta

final class GlyphTintResolverTests: XCTestCase {
    func testAutomaticTintUsesBatteryStatusColorsOnlyWhenUseful() {
        XCTAssertEqual(GlyphTintResolver.resolve(.status, mode: .filling, level: 80), .green)
        XCTAssertEqual(GlyphTintResolver.resolve(.status, mode: .deficit, level: 40), .amber)
        XCTAssertEqual(GlyphTintResolver.resolve(.status, mode: .draining, level: 10), .rose)
        XCTAssertEqual(GlyphTintResolver.resolve(.status, mode: .draining, level: 20), .amber)
        XCTAssertNil(GlyphTintResolver.resolve(.status, mode: .draining, level: 80))
    }

    func testChosenColorOverridesAutomaticBatteryStatus() {
        XCTAssertEqual(GlyphTintResolver.resolve(.blue, mode: .filling, level: 80), .blue)
        XCTAssertEqual(GlyphTintResolver.resolve(.green, mode: .deficit, level: 10), .green)
    }

    func testMonochromeSelectionSuppressesColor() {
        XCTAssertNil(GlyphTintResolver.resolve(.monochrome, mode: .filling, level: 100))
    }

    func testFreshConfigurationUsesAColoredIconByDefault() {
        XCTAssertEqual(Config().glyphTint, .blue)
    }

    func testLegacyMonochromeSettingMigrates() {
        XCTAssertEqual(GlyphTint.legacyValue(tinted: false), .monochrome)
        XCTAssertEqual(GlyphTint.legacyValue(tinted: true), .blue)
        XCTAssertEqual(GlyphTint.legacyValue(tinted: nil), .blue)
    }
}
