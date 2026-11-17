// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import Foundation

/// Limits menu-bar icon rendering when several observable sources invalidate together.
struct StatusIconRefreshGate {
    private let minimumInterval: TimeInterval
    private var lastRefresh: Date?

    init(minimumInterval: TimeInterval) {
        self.minimumInterval = max(0, minimumInterval)
    }

    func delayUntilAllowed(at date: Date) -> TimeInterval {
        guard let lastRefresh else { return 0 }
        return max(0, minimumInterval - date.timeIntervalSince(lastRefresh))
    }

    mutating func recordRefresh(at date: Date) {
        lastRefresh = date
    }
}
