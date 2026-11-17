// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import XCTest
@testable import Volta

/// Geometry of the self-drawn history chart (it replaced Swift Charts, which held ~60 MB of GPU memory).
final class TrendGeometryTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)   // a fixed instant

    func testPlotMapsTimeAndLevelToTheDrawingArea() {
        let layout = TrendLayout(size: CGSize(width: 300, height: 90), start: now - 86_400, end: now,
                                 labelColumn: 24, axisRow: 14)
        XCTAssertEqual(layout.plot, CGRect(x: 0, y: 4, width: 276, height: 72))
        XCTAssertEqual(layout.x(now - 86_400), 0, accuracy: 0.001)
        XCTAssertEqual(layout.x(now), 276, accuracy: 0.001)
        XCTAssertEqual(layout.x(now - 43_200), 138, accuracy: 0.001)
        XCTAssertEqual(layout.y(100), 4, accuracy: 0.001)
        XCTAssertEqual(layout.y(0), 76, accuracy: 0.001)
        XCTAssertEqual(layout.date(atX: 138).timeIntervalSince(now - 43_200), 0, accuracy: 1)
        XCTAssertEqual(layout.date(atX: -50), now - 86_400, "the pointer left of the plot clamps to its start")
    }

    func testTimeTicksFollowTheClock() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let end = calendar.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 11, minute: 50))!

        let day = TrendLayout.ticks(from: end - 86_400, to: end, span: .day, calendar: calendar)
        XCTAssertEqual(day.map { calendar.component(.hour, from: $0) }, [12, 18, 0, 6])

        let six = TrendLayout.ticks(from: end - 21_600, to: end, span: .sixHours, calendar: calendar)
        XCTAssertEqual(six.map { calendar.component(.hour, from: $0) }, [6, 8, 10])

        let week = TrendLayout.ticks(from: end - 604_800, to: end, span: .week, calendar: calendar)
        XCTAssertEqual(week.count, 7)
        XCTAssertTrue(week.allSatisfy { calendar.component(.hour, from: $0) == 0 && calendar.component(.minute, from: $0) == 0 })
    }

    func testSmoothCurveNeverOvershootsItsPoints() {
        // A battery curve must not dip below 0 %, rise above 100 % or wiggle between two samples.
        let points = [CGPoint(x: 0, y: 80), CGPoint(x: 10, y: 80), CGPoint(x: 20, y: 30), CGPoint(x: 21, y: 29),
                      CGPoint(x: 40, y: 100), CGPoint(x: 41, y: 100), CGPoint(x: 60, y: 60)]
        let pieces = MonotoneCurve.pieces(through: points)
        XCTAssertEqual(pieces.count, points.count - 1)
        for (piece, (a, b)) in zip(pieces, zip(points, points.dropFirst())) {
            XCTAssertEqual(piece.start, a)
            XCTAssertEqual(piece.end, b)
            for step in 0...20 {
                let y = piece.point(at: CGFloat(step) / 20).y
                XCTAssertGreaterThanOrEqual(y, min(a.y, b.y) - 0.0001)
                XCTAssertLessThanOrEqual(y, max(a.y, b.y) + 0.0001)
            }
        }
    }

    func testPointsAtTheSameMomentDoNotBreakTheCurve() {
        let pieces = MonotoneCurve.pieces(through: [CGPoint(x: 0, y: 50), CGPoint(x: 0, y: 51), CGPoint(x: 10, y: 60)])
        XCTAssertEqual(pieces.count, 1)
        XCTAssertTrue(pieces.allSatisfy { $0.c1.y.isFinite && $0.c2.y.isFinite })
    }
}
