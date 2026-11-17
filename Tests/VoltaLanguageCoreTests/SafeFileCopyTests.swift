// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import XCTest
@testable import VoltaLanguageCore

final class SafeFileCopyTests: XCTestCase {
    func testFailedCopyLeavesAnExistingDestinationUntouched() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appending(path: "tone.aiff")
        try Data("original".utf8).write(to: destination)
        let missingSource = directory.appending(path: "missing.aiff")

        XCTAssertThrowsError(try SafeFileCopy.copyReplacingItem(at: missingSource, to: destination))
        XCTAssertEqual(try Data(contentsOf: destination), Data("original".utf8))
    }

    func testCopyingAFileOntoItselfIsAHarmlessNoOp() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "tone.aiff")
        try Data("original".utf8).write(to: file)

        try SafeFileCopy.copyReplacingItem(at: file, to: file)

        XCTAssertEqual(try Data(contentsOf: file), Data("original".utf8))
    }

    func testSuccessfulCopyReplacesAnExistingDestination() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appending(path: "new.aiff")
        let destination = directory.appending(path: "tone.aiff")
        try Data("new tone".utf8).write(to: source)
        try Data("old tone".utf8).write(to: destination)

        try SafeFileCopy.copyReplacingItem(at: source, to: destination)

        XCTAssertEqual(try Data(contentsOf: destination), Data("new tone".utf8))
        XCTAssertEqual(try Data(contentsOf: source), Data("new tone".utf8))
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "VoltaTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
