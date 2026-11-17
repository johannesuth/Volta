// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import XCTest
import VoltaLanguageCore
@testable import Volta

final class ChartAxisLabelTests: XCTestCase {
    private let morning: Date = {
        var parts = DateComponents()
        parts.year = 2026; parts.month = 11; parts.day = 17; parts.hour = 7
        return Calendar.current.date(from: parts)!
    }()

    func testGermanHourLabelSaysUhrOnce() {
        let label = ChartAxisLabel.text(for: morning, span: .day, language: .german)
        XCTAssertEqual(label.components(separatedBy: "Uhr").count - 1, 1, label)
        XCTAssertTrue(label.hasPrefix("07"), label)
    }

    func testEnglishHourLabelSaysAMOrPM() {
        let label = ChartAxisLabel.text(for: morning, span: .day, language: .english)
        XCTAssertFalse(label.contains("Uhr"), label)
        XCTAssertEqual(label.replacingOccurrences(of: "\u{202F}", with: " "), "7 AM", "a bare \"07\" is ambiguous in English")
    }

    func testWeekLabelsUseTheAppLanguage() {
        XCTAssertEqual(ChartAxisLabel.text(for: morning, span: .week, language: .german), "Di")
        XCTAssertEqual(ChartAxisLabel.text(for: morning, span: .week, language: .english), "Tue")
    }
}
