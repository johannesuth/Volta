import XCTest
import VoltaLanguageCore
@testable import Volta

final class ConfigResetTests: XCTestCase {
    func testSettingsResetPreservesHistoryRetentionAndUserData() {
        var current = Config()
        current.keepDays = 365
        current.onboarded = true
        current.language = .english
        current.languageChosen = true
        current.pinned = ["headphones-1"]
        current.pollSeconds = 60

        let reset = current.resetForSettings()

        XCTAssertEqual(reset.keepDays, 365)
        XCTAssertTrue(reset.onboarded)
        XCTAssertEqual(reset.language, .english)
        XCTAssertTrue(reset.languageChosen)
        XCTAssertEqual(reset.pinned, ["headphones-1"])
        XCTAssertEqual(reset.pollSeconds, 20)
    }

    func testDashboardDefaultsToChargeFlowAndHistoryWithFewerAppRows() {
        let config = Config()
        XCTAssertEqual(config.hiddenTiles, [.vitals, .gadgets, .apps])
        XCTAssertEqual(config.tiles.filter { !config.hiddenTiles.contains($0) }, [.charge, .balance, .trend])
        XCTAssertEqual(config.appRows, 3)
    }

    func testPreviousAllHiddenDefaultMigratesToTheNewDefaultSections() {
        XCTAssertEqual(Config.migratedHiddenTiles([.trend, .vitals, .gadgets, .apps, .balance]), Config.defaultHiddenTiles)
        XCTAssertEqual(Config.migratedHiddenTiles([]), Config.defaultHiddenTiles)
        XCTAssertEqual(Config.migratedHiddenTiles([.trend, .apps]), [.trend, .apps])
    }
}
