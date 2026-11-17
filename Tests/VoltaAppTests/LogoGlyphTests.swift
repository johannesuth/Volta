// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import AppKit
import XCTest
@testable import Volta

/// The fifth menu-bar style: only Volta's logo (ring arc and bolt), drawn like a system icon.
@MainActor
final class LogoGlyphTests: XCTestCase {
    private func snapshot(level: Int, charging: Bool = false) -> PowerSnapshot {
        var s = PowerSnapshot()
        s.hasPack = true
        s.level = level
        s.onMains = charging
        s.filling = charging
        return s
    }

    private func config(tint: GlyphTint = .level) -> Config {
        var c = Config()
        c.glyph = .logo
        c.glyphTint = tint
        c.glyphWatts = false
        return c
    }

    func testLogoIsTheFifthChoiceInOneRow() {
        XCTAssertEqual(GlyphStyle.choices, [.cell, .cellPercent, .digits, .bare, .logo])
        XCTAssertEqual(GlyphStyle.logo.title.isEmpty, false)
    }

    func testLogoAdaptsToTheMenuBarLikeSystemIcons() {
        for tint in GlyphTint.allCases {
            let image = GlyphPainter.image(snapshot: snapshot(level: 72), clock: nil, cfg: config(tint: tint),
                                           darkBar: true, badges: [])
            XCTAssertTrue(image.isTemplate, "\(tint)")
            XCTAssertEqual(image.size.height, GlyphPainter.Metrics.height)
            XCTAssertLessThanOrEqual(image.size.width, 22, "about the size of a system menu-bar icon")
        }
    }

    func testLogoNeverNeedsARedraw() {
        // The logo shows neither level nor power state, so the menu bar never has to replace it.
        let signatures = [snapshot(level: 12), snapshot(level: 72), snapshot(level: 100, charging: true)].map {
            GlyphPainter.signature(snapshot: $0, clock: "1:00", cfg: config(), darkBar: true, badges: [])
        }
        XCTAssertEqual(Set(signatures).count, 1)
    }

    func testLogoDrawsTheRingAndTheBolt() {
        let image = GlyphPainter.image(snapshot: snapshot(level: 72), clock: nil, cfg: config(), darkBar: true, badges: [])
        let scale: CGFloat = 4
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(image.size.width * scale),
                                   pixelsHigh: Int(image.size.height * scale), bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = image.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: image.size))
        NSGraphicsContext.restoreGraphicsState()

        func alpha(_ x: CGFloat, _ y: CGFloat) -> CGFloat {
            // y measured from the top, like the bitmap.
            rep.colorAt(x: Int(x * scale), y: Int(y * scale))?.alphaComponent ?? 0
        }
        let mid = CGPoint(x: image.size.width / 2, y: image.size.height / 2)
        XCTAssertGreaterThan(alpha(mid.x, mid.y), 0.8, "the bolt crosses the centre")
        XCTAssertGreaterThan(alpha(mid.x, mid.y - GlyphPainter.Metrics.logoRadius), 0.8, "the bright arc starts at the top")
        let trackAlpha = alpha(mid.x - GlyphPainter.Metrics.logoRadius * 0.71, mid.y - GlyphPainter.Metrics.logoRadius * 0.71)
        XCTAssertGreaterThan(trackAlpha, 0.1, "the faint track closes the ring at the upper left")
        XCTAssertLessThan(trackAlpha, 0.6)
    }
}
