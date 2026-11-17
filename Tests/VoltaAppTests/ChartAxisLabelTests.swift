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

    func testEnglishHourLabelHasNoGermanSuffix() {
        let label = ChartAxisLabel.text(for: morning, span: .day, language: .english)
        XCTAssertFalse(label.contains("Uhr"), label)
        XCTAssertTrue(label.contains("7"), label)
    }

    func testWeekLabelsUseTheAppLanguage() {
        XCTAssertEqual(ChartAxisLabel.text(for: morning, span: .week, language: .german), "Di")
        XCTAssertEqual(ChartAxisLabel.text(for: morning, span: .week, language: .english), "Tue")
    }
}
