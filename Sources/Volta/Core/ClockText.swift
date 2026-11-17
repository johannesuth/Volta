// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import Foundation
import VoltaLanguageCore

/// Clock times such as "16:40 Uhr" / "4:40 PM", in the app's language rather than the system's.
enum ClockText {
    static func until(minutes: Int, from start: Date = .now, language: AppLanguage) -> String {
        let end = start.addingTimeInterval(TimeInterval(minutes) * 60)
        let locale = Locale(identifier: language == .german ? "de_DE" : "en_US")
        let time = end.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
            .replacingOccurrences(of: "\u{202F}", with: " ")
        return language == .german ? "\(time) Uhr" : time
    }
}
