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

    func testDashboardDefaultsToEverydayBatteryInformation() {
        let config = Config()
        XCTAssertEqual(config.hiddenTiles, [.balance, .gadgets, .apps])
        XCTAssertEqual(config.tiles.filter { !config.hiddenTiles.contains($0) }, [.charge, .vitals, .trend])
        XCTAssertFalse(config.showBatteryDetails, "mAh, voltage and current are opt-in technical values")
        XCTAssertEqual(config.appRows, 3)
    }

    func testEarlierUntouchedDefaultsMigrateToTheEverydaySections() {
        XCTAssertEqual(Config.migratedHiddenTiles([.trend, .vitals, .gadgets, .apps, .balance]), Config.defaultHiddenTiles)
        XCTAssertEqual(Config.migratedHiddenTiles([.vitals, .gadgets, .apps]), Config.defaultHiddenTiles)
        XCTAssertEqual(Config.migratedHiddenTiles([]), Config.defaultHiddenTiles)
        XCTAssertEqual(Config.migratedHiddenTiles([.trend, .apps]), [.trend, .apps])
    }

    func testEarlierDefaultSectionOrderMigratesButCustomOrderIsKept() {
        XCTAssertEqual(Config.migratedTileOrder([.charge, .balance, .trend, .vitals, .gadgets, .apps]), Config.defaultTileOrder)
        let custom: [TileKind] = [.charge, .apps, .trend, .vitals, .balance, .gadgets]
        XCTAssertEqual(Config.migratedTileOrder(custom), custom)
    }
}
