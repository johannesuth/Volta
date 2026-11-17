// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import XCTest
import VoltaLanguageCore
@testable import Volta

final class TrendChartTests: XCTestCase {
    private func mark(_ minutes: Double, _ level: Int, ac: Bool) -> Mark {
        Mark(t: 1_800_000_000 + minutes * 60, p: level, ac: ac, w: nil, c: nil)
    }

    func testChargingAndBatteryStretchesBecomeSeparateConnectedSegments() {
        let marks = [mark(0, 50, ac: false), mark(10, 48, ac: false), mark(20, 55, ac: true),
                     mark(30, 70, ac: true), mark(40, 69, ac: false)]
        let segments = TrendSegment.split(marks, maxGap: 45 * 60)

        XCTAssertEqual(segments.map(\.charging), [false, true, false])
        XCTAssertEqual(segments.map { $0.points.map(\.p) }, [[50, 48], [48, 55, 70], [70, 69]],
                       "each new stretch starts at the previous point so the line stays connected")
        XCTAssertEqual(Set(segments.map(\.id)).count, 3)
    }

    func testGapsAreBridgedAndColouredByWhatMustHaveHappened() {
        // No samples while the Mac charged in sleep: the level still rose, so the bridge is a charging stretch.
        let marks = [mark(0, 40, ac: false), mark(10, 40, ac: false), mark(200, 80, ac: false), mark(210, 79, ac: false),
                     mark(400, 60, ac: false)]
        let segments = TrendSegment.split(marks, maxGap: 45 * 60)

        XCTAssertEqual(segments.map(\.charging), [false, true, false])
        XCTAssertEqual(segments.map { $0.points.map(\.p) }, [[40, 40], [40, 80], [80, 79, 60]])
    }

    func testEmptyAndSingleInputs() {
        XCTAssertTrue(TrendSegment.split([], maxGap: 60).isEmpty)
        XCTAssertEqual(TrendSegment.split([mark(0, 40, ac: true)], maxGap: 60).map(\.charging), [true])
    }

    func testGapToleranceGrowsWithTheRange() {
        XCTAssertEqual(ChartSpan.sixHours.maxGap, 45 * 60)
        XCTAssertEqual(ChartSpan.day.maxGap, 45 * 60)
        XCTAssertEqual(ChartSpan.week.maxGap, 3 * 3600)
    }

    func testHoverReadoutUsesTheAppLanguage() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let date = calendar.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 14, minute: 5))!
        XCTAssertEqual(TrendReadout.text(level: 63, at: date, span: .day, language: .german), "14:05 Uhr · 63 %")
        XCTAssertEqual(TrendReadout.text(level: 63, at: date, span: .day, language: .english), "2:05 PM · 63%")
        XCTAssertEqual(TrendReadout.text(level: 63, at: date, span: .week, language: .german), "Di 14:05 Uhr · 63 %")
    }

    func testCompactPanelWithSlightlyLargerText() {
        // 2.3.0: text 1.11× the grid in a 352 pt panel. The user asked for a 5–10 % smaller panel
        // with about 5 % larger text: 1.11 × 1.05 ≈ 1.165.
        let dim = Dim()
        XCTAssertEqual(dim.pointSize(10), 11.65, accuracy: 0.001)
        // 2.3.2: 5–10 % narrower again, text unchanged.
        XCTAssertEqual(Dim.panelWidth, 312)
        XCTAssertLessThanOrEqual(Dim.panelWidth / 336, 0.95)
        XCTAssertEqual(Dim.chartHeight, 72, "the history chart was 112 pt tall in 2.3.0")
    }
}
