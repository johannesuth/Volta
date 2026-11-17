// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import AppKit
import SwiftUI
import XCTest
@testable import Volta

/// The dashboard sections are separate, softly rounded cards: a gap, a visible edge and a lighter surface.
@MainActor
final class CardSeparationTests: XCTestCase {
    private let tileHeight: CGFloat = 40

    private func render(_ scheme: ColorScheme, plate: Color) -> NSBitmapImageRep {
        let view = VStack(spacing: Dim.cardGap) {
            Tile { Color.clear.frame(height: tileHeight) }
            Tile { Color.clear.frame(height: tileHeight) }
        }
        .padding(8)
        .frame(width: 200)
        .background(plate)
        .environment(\.colorScheme, scheme)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = renderer.nsImage!
        return NSBitmapImageRep(data: image.tiffRepresentation!)!
    }

    private func luminance(_ rep: NSBitmapImageRep, x: CGFloat, y: CGFloat) -> CGFloat {
        let c = rep.colorAt(x: Int(x * 2), y: Int(y * 2))!.usingColorSpace(.deviceRGB)!
        return 0.2126 * c.redComponent + 0.7152 * c.greenComponent + 0.0722 * c.blueComponent
    }

    private func check(_ scheme: ColorScheme, plate: Color, file: StaticString = #filePath, line: UInt = #line) {
        let rep = render(scheme, plate: plate)
        let cardHeight = tileHeight + 2 * 8               // content + vertical padding
        let gapY = 8 + cardHeight + Dim.cardGap / 2
        let gap = luminance(rep, x: 100, y: gapY)
        let surface = luminance(rep, x: 100, y: 8 + cardHeight / 2)
        // Strongest contrast in the first point of the second card: its top edge.
        let edgeTop = 8 + cardHeight + Dim.cardGap
        let edge = stride(from: edgeTop, to: edgeTop + 1.5, by: 0.5).map { abs(luminance(rep, x: 100, y: $0) - gap) }.max()!

        XCTAssertGreaterThan(abs(surface - gap), 0.02, "the card surface stands out from the gap (\(scheme))", file: file, line: line)
        XCTAssertGreaterThan(edge, 0.06, "the card edge is visible (\(scheme))", file: file, line: line)
    }

    func testCardsAreVisiblySeparatedInDarkMode() {
        check(.dark, plate: Color(white: 0.17))
    }

    func testCardsAreVisiblySeparatedInLightMode() {
        check(.light, plate: Color(white: 0.89))
    }

    func testGapBetweenCardsIsSmallButClear() {
        XCTAssertGreaterThanOrEqual(Dim.cardGap, 7)
        XCTAssertLessThanOrEqual(Dim.cardGap, 9, "separated, but not as far apart as standalone widgets")
    }
}
