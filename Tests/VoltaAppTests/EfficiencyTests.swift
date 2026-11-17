// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import AppKit
import XCTest
@testable import Volta

/// Volta lives in the menu bar all day, so idle work must stay close to zero.
@MainActor
final class EfficiencyTests: XCTestCase {
    private func battery(level: Int) -> PowerSnapshot {
        var snapshot = PowerSnapshot()
        snapshot.hasPack = true
        snapshot.level = level
        return snapshot
    }

    private func signature(_ s: PowerSnapshot, dark: Bool = true, cfg: Config = Config()) -> String {
        GlyphPainter.signature(snapshot: s, clock: "3:12", cfg: cfg, darkBar: dark, badges: [])
    }

    func testIconIsOnlyReplacedWhenSomethingVisibleChanges() {
        // Replacing the status item image makes macOS re-snapshot it on every display; a feedback loop
        // through the appearance observer did this about five times per second while nothing changed.
        var a = battery(level: 64)
        a.packWatts = 5.2
        var b = a
        b.packWatts = 9.8
        b.milliamps = -1234
        b.celsius = 31
        b.taken = .now
        XCTAssertEqual(signature(a), signature(b), "values that are not drawn must not trigger a redraw")

        var lower = a
        lower.level = 63
        XCTAssertNotEqual(signature(a), signature(lower))
        XCTAssertNotEqual(signature(a, dark: true), signature(a, dark: false))

        var charging = a
        charging.onMains = true
        charging.filling = true
        XCTAssertNotEqual(signature(a), signature(charging))

        var mono = Config()
        mono.glyphTint = .monochrome
        XCTAssertNotEqual(signature(a), signature(a, cfg: mono))
    }

    func testClockOnlyCountsWhenTheIconShowsIt() {
        var cfg = Config()
        cfg.glyph = .cell
        let s = battery(level: 50)
        XCTAssertEqual(GlyphPainter.signature(snapshot: s, clock: "3:12", cfg: cfg, darkBar: true, badges: []),
                       GlyphPainter.signature(snapshot: s, clock: "3:11", cfg: cfg, darkBar: true, badges: []))
    }

    func testNumberFontIsCreatedOnce() {
        XCTAssertTrue(GlyphPainter.numberFont(size: 11.7) === GlyphPainter.numberFont(size: 11.7))
    }

    func testBackgroundWorkIsEventDrivenAndRare() {
        XCTAssertEqual(Telemetry.backgroundCadence, .seconds(60), "level changes arrive as power-source events")
        XCTAssertEqual(Telemetry.liveCadence, .milliseconds(1500), "the open dashboard stays live")
        XCTAssertEqual(GadgetHub.backgroundInterval, 120)
        XCTAssertEqual(GadgetHub.liveInterval, 10)
    }

    func testAccessoriesAreOnlyScannedWhenSomethingUsesThem() {
        var cfg = Config()
        cfg.hiddenTiles = [.gadgets]
        cfg.pinned = []
        cfg.gadgetFloor = 0
        XCTAssertFalse(GadgetHub.needsBackgroundScan(cfg))
        cfg.gadgetFloor = 20
        XCTAssertTrue(GadgetHub.needsBackgroundScan(cfg), "low-battery alerts for accessories need scans")
        cfg.gadgetFloor = 0
        cfg.pinned = ["AA:BB"]
        XCTAssertTrue(GadgetHub.needsBackgroundScan(cfg), "a pinned accessory is shown in the menu bar")
        cfg.pinned = []
        cfg.hiddenTiles = []
        cfg.tiles = TileKind.allCases
        XCTAssertTrue(GadgetHub.needsBackgroundScan(cfg))
    }

    func testProcessPathsAreLookedUpOncePerProcess() {
        var cache = ProcessPathCache()
        var lookups = 0
        let resolve: (Int32) -> String = { pid in lookups += 1; return "/Applications/App\(pid).app/Contents/MacOS/App" }

        XCTAssertEqual(cache.path(pid: 10, started: 100, resolve: resolve), "/Applications/App10.app/Contents/MacOS/App")
        _ = cache.path(pid: 10, started: 100, resolve: resolve)
        _ = cache.path(pid: 11, started: 100, resolve: resolve)
        XCTAssertEqual(lookups, 2)

        _ = cache.path(pid: 10, started: 200, resolve: resolve)
        XCTAssertEqual(lookups, 3, "a reused process ID is looked up again")

        cache.keepOnly(alive: [11])
        XCTAssertEqual(cache.count, 1)
    }

    func testAppIconsAreStoredSmall() throws {
        let calculator = URL(filePath: "/System/Applications/Calculator.app")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: calculator.path))
        let consumer = Consumer(id: calculator.path, title: "Calculator", watts: 1, fraction: 1, bundleURL: calculator)
        let icon = PowerLedger.shared.icon(for: consumer)
        let widest = icon.representations.map(\.pixelsWide).max() ?? 0
        XCTAssertGreaterThan(widest, 0)
        XCTAssertLessThanOrEqual(widest, 64, "a full app icon keeps every size up to 1024 px in memory")
    }

    func testAppEnergyRefreshesEveryFiveSeconds() {
        XCTAssertEqual(PowerLedger.refreshInterval, .seconds(5))
    }

}
