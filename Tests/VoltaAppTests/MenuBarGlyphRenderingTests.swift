// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import AppKit
import XCTest
@testable import Volta

@MainActor
final class MenuBarGlyphRenderingTests: XCTestCase {
    private func battery(level: Int) -> PowerSnapshot {
        var snapshot = PowerSnapshot()
        snapshot.hasPack = true
        snapshot.level = level
        return snapshot
    }

    private func config(tint: GlyphTint) -> Config {
        var config = Config()
        config.glyph = .cell
        config.glyphTint = tint
        return config
    }

    private func pixels(of image: NSImage, scale: CGFloat) -> NSBitmapImageRep {
        let size = image.size
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                   pixelsWide: Int((size.width * scale).rounded()),
                                   pixelsHigh: Int((size.height * scale).rounded()),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    private func luminance(_ color: NSColor) -> Double {
        0.2126 * color.redComponent + 0.7152 * color.greenComponent + 0.0722 * color.blueComponent
    }

    func testMenuBarArtworkIsRedrawnAtTheDisplayDensityOnWholePoints() {
        let image = GlyphPainter.image(snapshot: battery(level: 75), clock: nil, cfg: config(tint: .level),
                                       darkBar: true, badges: [])

        XCTAssertFalse(image.representations.isEmpty)
        XCTAssertTrue(image.representations.allSatisfy { $0 is NSCustomImageRep },
                      "Menu-bar artwork must be vector-drawn, not a pre-rasterized bitmap.")
        XCTAssertEqual(image.size.width, image.size.width.rounded())
        XCTAssertEqual(image.size.height, image.size.height.rounded())
    }

    func testColoredBatteryNumberIsLargeAndHighContrastOnRetina() {
        let image = GlyphPainter.image(snapshot: battery(level: 75), clock: nil, cfg: config(tint: .level),
                                       darkBar: true, badges: [])
        let rep = pixels(of: image, scale: 2)

        var digitTop = Int.max, digitBottom = Int.min
        var digitLight = 0.0, digitCount = 0, fillLight = 0.0, fillCount = 0
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                      color.alphaComponent > 0.95 else { continue }
                let light = luminance(color)
                if light < 0.2 {
                    digitTop = min(digitTop, y); digitBottom = max(digitBottom, y)
                    digitLight += light; digitCount += 1
                } else if light > 0.4 {
                    fillLight += light; fillCount += 1
                }
            }
        }

        XCTAssertGreaterThan(digitCount, 0)
        XCTAssertGreaterThan(fillCount, 0)
        XCTAssertGreaterThanOrEqual(digitBottom - digitTop + 1, 17,
                                    "Digits should be at least 8.5 pt tall so they stay legible from a distance.")
        XCTAssertGreaterThan(fillLight / Double(max(fillCount, 1)) - digitLight / Double(max(digitCount, 1)), 0.45)
    }

    func testCompactBatteryWithALargerNumber() {
        // A 32 × 15 pt body read as too large next to the clock; the 11.5 pt number of 2.2.1 as too small.
        let body = GlyphPainter.Metrics.cell
        XCTAssertEqual(body, CGSize(width: 30, height: 14))
        XCTAssertEqual(GlyphPainter.Metrics.number, 13)
        XCTAssertEqual(GlyphPainter.Metrics.numberFull, 11.5)
        XCTAssertLessThan(GlyphPainter.Metrics.numberFull, GlyphPainter.Metrics.number)

        let image = GlyphPainter.image(snapshot: battery(level: 64), clock: nil, cfg: config(tint: .level),
                                       darkBar: true, badges: [])
        XCTAssertLessThanOrEqual(image.size.width, 35, "body, nub and 1 pt padding per side (was 37 pt)")
        XCTAssertEqual(image.size.height, GlyphPainter.Metrics.height)
    }

    func testNumberIsAboutFivePercentLighterThanBold() {
        // Bold (700) read slightly too heavy; the number uses weight 640 on the system font's weight axis.
        XCTAssertEqual(GlyphPainter.Metrics.numberWeight, 640)
        func ink(_ font: NSFont) -> Double {
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 80, pixelsHigh: 40, bitsPerSample: 8,
                                       samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                       bytesPerRow: 0, bitsPerPixel: 0)!
            rep.size = NSSize(width: 40, height: 20)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            NSAttributedString(string: "88", attributes: [.font: font, .foregroundColor: NSColor.black]).draw(at: NSPoint(x: 2, y: 2))
            NSGraphicsContext.restoreGraphicsState()
            var sum = 0.0
            for y in 0..<40 { for x in 0..<80 { sum += Double(rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) } }
            return sum
        }
        let bold = ink(NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .bold))
        let number = ink(GlyphPainter.numberFont(size: 13))
        XCTAssertEqual(number / bold, 0.95, accuracy: 0.02, "ink ratio \(number / bold)")
    }

    func testLevelColorsAreLightGreenYellowAndRed() {
        func hueDegrees(_ color: NSColor) -> CGFloat { (color.usingColorSpace(.deviceRGB)?.hueComponent ?? 0) * 360 }
        let green = GlyphPainter.levelColor(.high), yellow = GlyphPainter.levelColor(.medium), red = GlyphPainter.levelColor(.low)

        XCTAssertTrue((100...150).contains(hueDegrees(green)), "green hue \(hueDegrees(green))")
        XCTAssertTrue((40...58).contains(hueDegrees(yellow)), "yellow hue \(hueDegrees(yellow))")
        XCTAssertTrue(hueDegrees(red) < 12 || hueDegrees(red) > 348, "red hue \(hueDegrees(red))")
        for color in [green, yellow, red] {
            XCTAssertGreaterThan(luminance(color.usingColorSpace(.deviceRGB)!), 0.55, "level colours should be light")
        }
    }

    func testNumberHasOneColorOnBothSidesOfTheFillEdge() {
        // At 64 % the "4" straddles the fill edge; it must not turn half white.
        for level in [15, 50, 64, 100] {
            let image = GlyphPainter.image(snapshot: battery(level: level), clock: nil, cfg: config(tint: .level),
                                           darkBar: true, badges: [])
            let rep = pixels(of: image, scale: 2)
            let body = GlyphPainter.Metrics.cell
            let top = Int(((GlyphPainter.Metrics.height - body.height) / 2 * 2).rounded()) + 3
            let bottom = top + Int(body.height * 2) - 6
            let edge = Int(((1 + body.width * CGFloat(level) / 100) * 2).rounded())

            var white = 0, darkLeft = 0, darkRight = 0
            for y in top..<bottom {
                for x in 4..<(Int(body.width * 2) - 2) {
                    guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), c.alphaComponent > 0.95 else { continue }
                    if luminance(c) > 0.9 { white += 1 }
                    if luminance(c) < 0.2 { if x < edge { darkLeft += 1 } else { darkRight += 1 } }
                }
            }
            XCTAssertEqual(white, 0, "no white digit parts at \(level) %")
            if level == 64 {
                XCTAssertGreaterThan(darkLeft, 30, "dark digits over the fill")
                XCTAssertGreaterThan(darkRight, 10, "the same dark digits continue over the empty part")
            }
        }
    }

    func testDarkNumberContrastsWithTheEmptyTrackOnDarkAndLightBars() {
        func lin(_ v: CGFloat) -> CGFloat { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        func relative(_ c: NSColor) -> CGFloat {
            let c = c.usingColorSpace(.sRGB)!
            return 0.2126 * lin(c.redComponent) + 0.7152 * lin(c.greenComponent) + 0.0722 * lin(c.blueComponent)
        }
        for (dark, bar) in [(true, CGFloat(0.12)), (false, CGFloat(0.92))] {
            let ink = GlyphPainter.ink(selection: .level, level: 64, darkBar: dark)
            let n = ink.neutral.usingColorSpace(.sRGB)!
            let a = ink.trackAlpha
            let track = NSColor(srgbRed: bar * (1 - a) + n.redComponent * a, green: bar * (1 - a) + n.greenComponent * a,
                                blue: bar * (1 - a) + n.blueComponent * a, alpha: 1)
            let ratio = (relative(track) + 0.05) / (relative(ink.figure) + 0.05)
            XCTAssertGreaterThan(ratio, 4.0, "number vs empty track contrast on a \(dark ? "dark" : "light") bar: \(ratio)")
            for band in [LevelBand.high, .medium, .low] {
                let fill = (relative(GlyphPainter.levelColor(band)) + 0.05) / (relative(ink.figure) + 0.05)
                XCTAssertGreaterThan(fill, 6.0, "number vs \(band) fill")
            }
        }
    }

    func testMonochromeNumberIsCutOutOfAnOpaqueBattery() {
        let image = GlyphPainter.image(snapshot: battery(level: 75), clock: nil, cfg: config(tint: .monochrome),
                                       darkBar: true, badges: [])
        XCTAssertTrue(image.isTemplate)
        let rep = pixels(of: image, scale: 2)

        var opaque: [(Int, Int)] = []
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.9 {
                opaque.append((x, y))
            }
        }
        guard let minX = opaque.map(\.0).min(), let maxX = opaque.map(\.0).max(),
              let minY = opaque.map(\.1).min(), let maxY = opaque.map(\.1).max() else {
            return XCTFail("The battery body was not drawn.")
        }
        // The opaque bounds are the filled part of the body; the number is cut out of it.
        var holes = 0
        for y in (minY + 3)...(maxY - 3) {
            for x in (minX + 3)...(maxX - 3) where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 1) < 0.1 {
                holes += 1
            }
        }
        XCTAssertGreaterThan(holes, 40, "The level digits should be knocked out of the filled battery body.")
    }
}
