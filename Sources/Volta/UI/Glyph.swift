import AppKit
import CoreText

/// A connected accessory shown beside the battery in the menu bar.
struct GlyphBadge: Hashable, Sendable {
    var symbol: String
    var level: Int?
}

/// Colours for one rendering of the menu-bar artwork, chosen for the current bar appearance.
struct GlyphInk: @unchecked Sendable {
    var template: Bool
    var neutral: NSColor
    var fill: NSColor
    var caption: NSColor
    var figure: NSColor
    var trackAlpha: CGFloat
}

/// Menu-bar artwork, drawn by AppKit at the screen's own pixel density on whole points so digits
/// stay crisp. A new image is produced for every repaint; nothing is pre-rasterised.
@MainActor
enum GlyphPainter {
    enum Metrics {
        static let height: CGFloat = 22
        static let spacing: CGFloat = 4
        static let cell = CGSize(width: 32, height: 15)
        static let bareCell = CGSize(width: 25, height: 12)
        static let cellRadius: CGFloat = 4.5
        static let nub = CGSize(width: 2, height: 5)
        static let nubGap: CGFloat = 1
        static let number: CGFloat = 12
        static let numberFull: CGFloat = 11
        static let caption: CGFloat = 13
        static let badgeText: CGFloat = 11.5
        static let ring: CGFloat = 18
    }

    static func color(for tint: GlyphTint) -> NSColor? {
        switch tint {
        case .blue: NSColor(srgbRed: 0.42, green: 0.63, blue: 0.82, alpha: 1)
        case .green: NSColor(srgbRed: 0.41, green: 0.69, blue: 0.55, alpha: 1)
        case .teal: NSColor(srgbRed: 0.36, green: 0.66, blue: 0.70, alpha: 1)
        case .violet: NSColor(srgbRed: 0.52, green: 0.56, blue: 0.77, alpha: 1)
        case .amber: NSColor(srgbRed: 0.83, green: 0.66, blue: 0.39, alpha: 1)
        case .rose: NSColor(srgbRed: 0.74, green: 0.54, blue: 0.64, alpha: 1)
        case .status, .monochrome: nil
        }
    }

    static func ink(selection: GlyphTint, mode: FlowMode, level: Int, darkBar: Bool) -> GlyphInk {
        let figure = NSColor(srgbRed: 0.06, green: 0.07, blue: 0.09, alpha: 1)
        guard let tint = GlyphTintResolver.resolve(selection, mode: mode, level: level),
              let base = color(for: tint) else {
            return GlyphInk(template: true, neutral: .black, fill: .black, caption: .black, figure: .black, trackAlpha: 0.35)
        }
        if darkBar {
            let bright = base.blended(withFraction: 0.2, of: .white) ?? base
            return GlyphInk(template: false, neutral: .white, fill: bright, caption: bright, figure: figure, trackAlpha: 0.45)
        }
        let deep = base.blended(withFraction: 0.35, of: .black) ?? base
        return GlyphInk(template: false, neutral: .black, fill: base, caption: deep, figure: figure, trackAlpha: 0.22)
    }

    static func image(snapshot s: PowerSnapshot, clock: String?, cfg: Config, darkBar: Bool,
                      badges: [GlyphBadge]) -> NSImage {
        let ink = ink(selection: cfg.glyphTint, mode: s.mode, level: s.level, darkBar: darkBar)
        let watts: String? = cfg.glyphWatts
            ? String(format: "%.0f W", abs(s.onMains ? s.mainsWatts : s.packWatts)) : nil
        let drawing = GlyphDrawing(level: s.level, mode: s.mode, style: cfg.glyph, ink: ink, clock: clock,
                                   watts: watts, badges: badges,
                                   hideNumber: cfg.glyphQuietWhenFull && s.mode == .topped)
        let size = NSSize(width: ceil(drawing.width), height: Metrics.height)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            drawing.draw(in: context, bounds: rect)
            return true
        }
        image.isTemplate = ink.template
        image.accessibilityDescription = "Volta"
        return image
    }
}

/// The geometry and drawing for one menu-bar image. Value-only so it can be redrawn at any scale.
struct GlyphDrawing: @unchecked Sendable {
    private typealias M = GlyphPainter.Metrics

    private enum Part {
        case badge(GlyphBadge)
        case cell(number: Bool)
        case bareCell
        case caption(String)
        case ring(number: Bool)
    }

    let level: Int
    let mode: FlowMode
    let ink: GlyphInk
    private let parts: [Part]

    init(level: Int, mode: FlowMode, style: GlyphStyle, ink: GlyphInk, clock: String?, watts: String?,
         badges: [GlyphBadge], hideNumber: Bool) {
        self.level = level
        self.mode = mode
        self.ink = ink
        var parts: [Part] = badges.map(Part.badge)
        switch style {
        case .cell: parts.append(.cell(number: !hideNumber))
        case .bare: parts.append(.bareCell)
        case .cellPercent:
            if !hideNumber { parts.append(.caption("\(level) %")) }
            parts.append(.bareCell)
        case .ring: parts.append(.ring(number: !hideNumber))
        case .digits: parts.append(.caption("\(level) %"))
        case .clock: parts.append(.caption(clock.map { "\($0) · \(level) %" } ?? "\(level) %"))
        }
        if let watts { parts.append(.caption(watts)) }
        self.parts = parts
    }

    private var plugged: Bool { [.filling, .topped, .resting].contains(mode) }

    var width: CGFloat {
        let widths = parts.map(width(of:))
        return widths.reduce(0, +) + M.spacing * CGFloat(max(widths.count - 1, 0)) + 2
    }

    // MARK: Layout

    private func width(of part: Part) -> CGFloat {
        switch part {
        case .badge(let badge):
            return symbolSize(badge.symbol, pointSize: 12, weight: .semibold).width + 2
                + textWidth(badge.level.map(String.init) ?? "–", size: M.badgeText, weight: .semibold)
        case .cell(let number):
            let body = number ? M.cell.width : M.bareCell.width
            return body + M.nubGap + M.nub.width + (plugged ? 1 + boltSize.width : 0)
        case .bareCell:
            return M.bareCell.width + M.nubGap + M.nub.width + (plugged ? 1 + boltSize.width : 0)
        case .caption(let text):
            return textWidth(text, size: M.caption, weight: .medium)
        case .ring:
            return M.ring
        }
    }

    // MARK: Drawing

    func draw(in context: CGContext, bounds: CGRect) {
        let scale = max(1, abs(context.userSpaceToDeviceSpaceTransform.a))
        let snap = { (value: CGFloat) in (value * scale).rounded() / scale }
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        defer { context.endTransparencyLayer() }
        var x: CGFloat = 1
        let midY = bounds.midY
        for part in parts {
            let start = snap(x)
            draw(part, at: start, midY: midY, in: context, snap: snap)
            x = start + width(of: part) + M.spacing
        }
    }

    private func draw(_ part: Part, at x: CGFloat, midY: CGFloat, in context: CGContext, snap: (CGFloat) -> CGFloat) {
        switch part {
        case .badge(let badge):
            let color = ink.template ? NSColor.black : ink.neutral
            let size = symbolSize(badge.symbol, pointSize: 12, weight: .semibold)
            drawSymbol(badge.symbol, pointSize: 12, weight: .semibold, color: color,
                       in: CGRect(x: x, y: snap(midY - size.height / 2), width: size.width, height: size.height))
            drawCaption(badge.level.map(String.init) ?? "–", size: M.badgeText, weight: .semibold, color: color,
                        x: x + size.width + 2, midY: midY, in: context, snap: snap)
        case .cell(let number):
            drawCell(size: number ? M.cell : M.bareCell, number: number, at: x, midY: midY, in: context, snap: snap)
        case .bareCell:
            drawCell(size: M.bareCell, number: false, at: x, midY: midY, in: context, snap: snap)
        case .caption(let text):
            drawCaption(text, size: M.caption, weight: .medium, color: ink.template ? .black : ink.caption,
                        x: x, midY: midY, in: context, snap: snap)
        case .ring(let number):
            drawRing(number: number, at: x, midY: midY, in: context, snap: snap)
        }
    }

    private func drawCell(size: CGSize, number: Bool, at x: CGFloat, midY: CGFloat, in context: CGContext,
                          snap: (CGFloat) -> CGFloat) {
        let body = CGRect(x: x, y: snap(midY - size.height / 2), width: size.width, height: size.height)
        let fraction = CGFloat(min(max(level, 0), 100)) / 100
        if number {
            let shape = NSBezierPath(roundedRect: body, xRadius: M.cellRadius, yRadius: M.cellRadius)
            ink.neutral.withAlphaComponent(ink.trackAlpha).setFill()
            shape.fill()
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: CGRect(x: body.minX, y: body.minY, width: snap(body.width * fraction),
                                      height: body.height)).addClip()
            ink.fill.setFill()
            shape.fill()
            NSGraphicsContext.restoreGraphicsState()

            let text = "\(level)"
            let line = makeLine(text, size: level >= 100 ? M.numberFull : M.number, weight: .bold,
                                color: ink.template ? .black : ink.figure)
            context.saveGState()
            if ink.template { context.setBlendMode(.destinationOut) }
            drawCentered(line, in: body, context: context, snap: snap)
            context.restoreGState()
        } else {
            let outline = NSBezierPath(roundedRect: body.insetBy(dx: 0.5, dy: 0.5), xRadius: 3.4, yRadius: 3.4)
            outline.lineWidth = 1
            ink.neutral.withAlphaComponent(ink.template ? 0.55 : 0.6).setStroke()
            outline.stroke()
            let inner = body.insetBy(dx: 2, dy: 2)
            let filled = CGRect(x: inner.minX, y: inner.minY, width: max(2, snap(inner.width * fraction)),
                                height: inner.height)
            ink.fill.setFill()
            NSBezierPath(roundedRect: filled, xRadius: 1.6, yRadius: 1.6).fill()
        }

        let nub = CGRect(x: body.maxX + M.nubGap, y: snap(midY - M.nub.height / 2),
                         width: M.nub.width, height: M.nub.height)
        ink.neutral.withAlphaComponent(ink.template ? 0.5 : 0.55).setFill()
        NSBezierPath(roundedRect: nub, xRadius: 1, yRadius: 1).fill()

        if plugged {
            let bolt = boltSize
            drawSymbol(boltName, pointSize: 9, weight: .black, color: ink.template ? .black : ink.caption,
                       in: CGRect(x: nub.maxX + 1, y: snap(midY - bolt.height / 2), width: bolt.width, height: bolt.height))
        }
    }

    private func drawRing(number: Bool, at x: CGFloat, midY: CGFloat, in context: CGContext, snap: (CGFloat) -> CGFloat) {
        let box = CGRect(x: x, y: snap(midY - M.ring / 2), width: M.ring, height: M.ring)
        let circle = box.insetBy(dx: 1.2, dy: 1.2)
        let track = NSBezierPath(ovalIn: circle)
        track.lineWidth = 2.2
        ink.neutral.withAlphaComponent(ink.template ? 0.35 : 0.4).setStroke()
        track.stroke()

        let arc = NSBezierPath()
        arc.appendArc(withCenter: CGPoint(x: circle.midX, y: circle.midY), radius: circle.width / 2,
                      startAngle: 90, endAngle: 90 - 360 * CGFloat(min(max(level, 0), 100)) / 100, clockwise: true)
        arc.lineWidth = 2.2
        arc.lineCapStyle = .round
        ink.fill.setStroke()
        arc.stroke()

        if plugged {
            let bolt = boltSize
            drawSymbol("bolt.fill", pointSize: 9, weight: .black, color: ink.template ? .black : ink.fill,
                       in: CGRect(x: snap(box.midX - bolt.width / 2), y: snap(box.midY - bolt.height / 2),
                                  width: bolt.width, height: bolt.height))
        } else if number {
            let line = makeLine("\(level)", size: level >= 100 ? 7 : 8.5, weight: .bold,
                                color: ink.template ? .black : ink.neutral)
            drawCentered(line, in: box, context: context, snap: snap)
        }
    }

    // MARK: Text and symbols

    private var boltName: String { mode == .resting ? "leaf.fill" : "bolt.fill" }
    private var boltSize: CGSize { symbolSize(boltName, pointSize: 9, weight: .black) }

    private func font(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
    }

    private func makeLine(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> CTLine {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font(size, weight),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor,
        ]
        return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    }

    private func textWidth(_ text: String, size: CGFloat, weight: NSFont.Weight) -> CGFloat {
        CGFloat(CTLineGetTypographicBounds(makeLine(text, size: size, weight: weight, color: .black), nil, nil, nil))
    }

    /// Centres the glyphs' actual ink on a pixel-aligned baseline.
    private func drawCentered(_ line: CTLine, in rect: CGRect, context: CGContext, snap: (CGFloat) -> CGFloat) {
        let inkBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: snap(rect.midX - inkBounds.width / 2 - inkBounds.minX),
                                       y: snap(rect.midY - inkBounds.height / 2 - inkBounds.minY))
        CTLineDraw(line, context)
    }

    private func drawCaption(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, x: CGFloat,
                             midY: CGFloat, in context: CGContext, snap: (CGFloat) -> CGFloat) {
        let line = makeLine(text, size: size, weight: weight, color: color)
        context.saveGState()
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: x, y: snap(midY - font(size, weight).capHeight / 2))
        CTLineDraw(line, context)
        context.restoreGState()
    }

    private func symbolImage(_ name: String, pointSize: CGFloat, weight: NSFont.Weight, color: NSColor? = nil) -> NSImage? {
        var configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        if let color { configuration = configuration.applying(.init(paletteColors: [color])) }
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(configuration)
    }

    private func symbolSize(_ name: String, pointSize: CGFloat, weight: NSFont.Weight) -> CGSize {
        symbolImage(name, pointSize: pointSize, weight: weight)?.size ?? CGSize(width: pointSize, height: pointSize)
    }

    private func drawSymbol(_ name: String, pointSize: CGFloat, weight: NSFont.Weight, color: NSColor, in rect: CGRect) {
        symbolImage(name, pointSize: pointSize, weight: weight, color: color)?
            .draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    }
}
