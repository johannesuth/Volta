// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import Foundation

/// Persists intentional history clears and invalidates asynchronous work submitted before a clear.
public struct HistoryImportGate {
    private let markerURL: URL
    public private(set) var historyWasCleared: Bool
    public private(set) var generation: UInt64 = 0

    public init(markerURL: URL) {
        self.markerURL = markerURL
        self.historyWasCleared = FileManager.default.fileExists(atPath: markerURL.path(percentEncoded: false))
    }

    public var powerTickToken: UInt64 { generation }

    public mutating func markHistoryCleared() throws {
        let parent = markerURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        try Data("Volta history cleared\n".utf8).write(to: markerURL, options: .atomic)
        historyWasCleared = true
        generation &+= 1
    }

    public func automaticImportToken(markCount: Int) -> UInt64? {
        guard !historyWasCleared, markCount < 12 else { return nil }
        return generation
    }

    public func manualImportToken() -> UInt64 { generation }

    public func canCommitAutomaticImport(startedAt token: UInt64) -> Bool {
        !historyWasCleared && token == generation
    }

    public func canCommitManualImport(startedAt token: UInt64) -> Bool {
        token == generation
    }

    public func canCommitPowerTick(submittedAt token: UInt64) -> Bool {
        token == generation
    }
}
