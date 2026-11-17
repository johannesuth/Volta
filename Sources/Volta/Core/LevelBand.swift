// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import Foundation

/// Charge bands for the level-coloured menu-bar battery: green above 50 %, yellow down to 21 %, red at 20 % or less.
enum LevelBand: Equatable {
    case high, medium, low

    init(level: Int) {
        self = level > 50 ? .high : (level > 20 ? .medium : .low)
    }
}
