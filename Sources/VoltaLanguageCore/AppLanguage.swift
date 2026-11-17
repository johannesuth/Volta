// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import Foundation

public enum AppLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case german = "de"
    case english = "en"

    public var id: String { rawValue }
    public var localeIdentifier: String { rawValue }
    public var displayName: String { self == .german ? "Deutsch" : "English" }

    public static func detected(from localeIdentifier: String) -> AppLanguage {
        localeIdentifier.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first == "en"
            ? .english
            : .german
    }

    public static func shouldPresentOnboarding(languageChosen: Bool) -> Bool {
        !languageChosen
    }

    public func localized(german: String, english: String) -> String {
        self == .english ? english : german
    }
}
