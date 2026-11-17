// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import XCTest
@testable import VoltaLanguageCore

final class HistoryImportGateTests: XCTestCase {
    func testManualClearPreventsAutomaticImportAfterRelaunch() throws {
        let marker = try markerURL()
        defer { try? FileManager.default.removeItem(at: marker.deletingLastPathComponent()) }

        var firstLaunch = HistoryImportGate(markerURL: marker)
        XCTAssertNotNil(firstLaunch.automaticImportToken(markCount: 0))
        try firstLaunch.markHistoryCleared()

        let nextLaunch = HistoryImportGate(markerURL: marker)
        XCTAssertNil(nextLaunch.automaticImportToken(markCount: 0))
    }

    func testClearInvalidatesAnImportAlreadyInFlightAndOldPowerTicks() throws {
        let marker = try markerURL()
        defer { try? FileManager.default.removeItem(at: marker.deletingLastPathComponent()) }

        var gate = HistoryImportGate(markerURL: marker)
        let importToken = try XCTUnwrap(gate.automaticImportToken(markCount: 0))
        let queuedTickToken = gate.powerTickToken
        try gate.markHistoryCleared()

        XCTAssertFalse(gate.canCommitAutomaticImport(startedAt: importToken))
        XCTAssertFalse(gate.canCommitPowerTick(submittedAt: queuedTickToken))
        XCTAssertTrue(gate.canCommitPowerTick(submittedAt: gate.powerTickToken))
    }

    func testExplicitManualImportRemainsAvailableAfterClear() throws {
        let marker = try markerURL()
        defer { try? FileManager.default.removeItem(at: marker.deletingLastPathComponent()) }

        var gate = HistoryImportGate(markerURL: marker)
        try gate.markHistoryCleared()
        let token = gate.manualImportToken()

        XCTAssertTrue(gate.canCommitManualImport(startedAt: token))
    }

    private func markerURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "VoltaHistoryGateTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "history-cleared.marker")
    }
}
