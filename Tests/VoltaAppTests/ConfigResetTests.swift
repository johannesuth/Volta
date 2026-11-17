// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

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
        current.fahrenheit = true

        let reset = current.resetForSettings()

        XCTAssertEqual(reset.keepDays, 365)
        XCTAssertTrue(reset.onboarded)
        XCTAssertEqual(reset.language, .english)
        XCTAssertTrue(reset.languageChosen)
        XCTAssertEqual(reset.pinned, ["headphones-1"])
        XCTAssertFalse(reset.fahrenheit)
    }

    func testDashboardShowsHealthAppEnergyAndHistoryByDefault() {
        let config = Config()
        XCTAssertEqual(config.hiddenTiles, [.balance, .gadgets])
        XCTAssertEqual(config.tiles.filter { !config.hiddenTiles.contains($0) }, [.charge, .vitals, .apps, .trend])
        XCTAssertEqual(config.expansion.openTiles, [.vitals, .apps], "history starts collapsed")
        XCTAssertFalse(config.showBatteryDetails, "mAh, voltage and current are opt-in technical values")
        XCTAssertEqual(config.appRows, 3)
    }

    func testEarlierUntouchedDefaultsMigrateToTheCurrentSections() {
        for earlier: [TileKind] in [[.trend, .vitals, .gadgets, .apps, .balance], [.vitals, .gadgets, .apps], [.balance, .gadgets, .apps], []] {
            XCTAssertEqual(Config.migratedHiddenTiles(earlier), Config.defaultHiddenTiles, "\(earlier)")
        }
        XCTAssertEqual(Config.migratedHiddenTiles([.trend, .apps]), [.trend, .apps])
    }

    func testEarlierDefaultSectionOrderMigratesButCustomOrderIsKept() {
        XCTAssertEqual(Config.migratedTileOrder([.charge, .balance, .trend, .vitals, .gadgets, .apps]), Config.defaultTileOrder)
        XCTAssertEqual(Config.migratedTileOrder([.charge, .vitals, .trend, .balance, .gadgets, .apps]), Config.defaultTileOrder)
        let custom: [TileKind] = [.charge, .apps, .trend, .vitals, .balance, .gadgets]
        XCTAssertEqual(Config.migratedTileOrder(custom), custom)
    }

    func testEarlierDefaultOpenSectionsMigrate() {
        XCTAssertEqual(Config.migratedExpansion(TileExpansion(openTiles: [.vitals])), TileExpansion.standard)
        XCTAssertEqual(Config.migratedExpansion(TileExpansion(openTiles: [.trend])), TileExpansion(openTiles: [.trend]))
    }

    func testHistoryCanBeHiddenAndShownAgainInTheMenu() {
        var config = Config()
        config.setTile(.trend, shown: false)
        XCTAssertFalse(config.tiles.filter { !config.hiddenTiles.contains($0) }.contains(.trend))
        config.setTile(.trend, shown: false)
        XCTAssertEqual(config.hiddenTiles.filter { $0 == .trend }.count, 1, "hiding twice keeps one entry")
        config.setTile(.trend, shown: true)
        XCTAssertTrue(config.tiles.filter { !config.hiddenTiles.contains($0) }.contains(.trend))
        XCTAssertEqual(config.hiddenTiles, Config.defaultHiddenTiles)
    }

}
