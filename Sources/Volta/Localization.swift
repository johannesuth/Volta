// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import Foundation
import VoltaLanguageCore

/// Short runtime copy for strings assembled outside SwiftUI's localization table.
enum Copy {
    static var language: AppLanguage { ConfigStore.shared.c.language }

    static func text(_ german: String, _ english: String) -> String {
        language.localized(german: german, english: english)
    }
}
