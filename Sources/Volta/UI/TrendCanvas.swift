// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import SwiftUI
import VoltaLanguageCore

// MARK: - Geometry

/// Maps time and charge level onto the chart's drawing area and picks the time-axis ticks.
struct TrendLayout {
    let plot: CGRect
    let start: Date
    let end: Date

    /// `labelColumn` is the width kept free on the right for 0 / 50 / 100, `axisRow` the height kept free
    /// below for the time labels. A small top inset keeps the line's round caps inside the frame.
    init(size: CGSize, start: Date, end: Date, labelColumn: CGFloat, axisRow: CGFloat, topInset: CGFloat = 4) {
        self.start = start
        self.end = end
        plot = CGRect(x: 0, y: topInset, width: max(size.width - labelColumn, 1),
                      height: max(size.height - axisRow - topInset, 1))
    }

    private var duration: TimeInterval { max(end.timeIntervalSince(start), 1) }

    func x(_ date: Date) -> CGFloat {
        plot.minX + CGFloat(date.timeIntervalSince(start) / duration) * plot.width
    }

    func y(_ level: Double) -> CGFloat {
        plot.maxY - CGFloat(min(max(level, 0), 100) / 100) * plot.height
    }

    func date(atX x: CGFloat) -> Date {
        let fraction = min(max((x - plot.minX) / plot.width, 0), 1)
        return start + duration * Double(fraction)
    }

    /// Clock-aligned ticks: every 2 hours (6 h range), every 6 hours (24 h), every midnight (7 days).
    static func ticks(from start: Date, to end: Date, span: ChartSpan, calendar: Calendar = .current) -> [Date] {
        var out: [Date] = []
        if span == .week {
            var day = calendar.startOfDay(for: start)
            if day < start { day = calendar.date(byAdding: .day, value: 1, to: day) ?? end }
            while day <= end {
                out.append(day)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
            return out
        }
        let every = span == .day ? 6 : 2
        var hour = calendar.dateInterval(of: .hour, for: start)?.start ?? start
        if hour < start { hour = calendar.date(byAdding: .hour, value: 1, to: hour) ?? end }
        while hour <= end {
            if calendar.component(.hour, from: hour) % every == 0 { out.append(hour) }
            guard let next = calendar.date(byAdding: .hour, value: 1, to: hour) else { break }
            hour = next
        }
        return out
    }
}

/// A smooth line through the samples that never overshoots them (Fritsch–Carlson monotone cubic),
/// the same kind of curve Swift Charts draws with `.monotone`.
enum MonotoneCurve {
    struct Piece: Equatable {
        let start: CGPoint
        let c1: CGPoint
        let c2: CGPoint
        let end: CGPoint

        func point(at t: CGFloat) -> CGPoint {
            let u = 1 - t
            let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
            return CGPoint(x: a * start.x + b * c1.x + c * c2.x + d * end.x,
                           y: a * start.y + b * c1.y + c * c2.y + d * end.y)
        }
    }

    static func pieces(through input: [CGPoint]) -> [Piece] {
        // Samples taken at the same moment would divide by zero; the later one wins.
        var points: [CGPoint] = []
        for p in input {
            if let last = points.last, abs(p.x - last.x) < 1e-9 { points[points.count - 1] = p } else { points.append(p) }
        }
        let n = points.count
        guard n >= 2 else { return [] }

        var slopes = [CGFloat](repeating: 0, count: n - 1)
        for i in 0..<(n - 1) { slopes[i] = (points[i + 1].y - points[i].y) / (points[i + 1].x - points[i].x) }

        var tangents = [CGFloat](repeating: 0, count: n)
        tangents[0] = slopes[0]
        tangents[n - 1] = slopes[n - 2]
        if n > 2 {
            for i in 1..<(n - 1) {
                tangents[i] = slopes[i - 1] * slopes[i] <= 0 ? 0 : (slopes[i - 1] + slopes[i]) / 2
            }
        }
        for i in 0..<(n - 1) {
            if slopes[i] == 0 {
                tangents[i] = 0
                tangents[i + 1] = 0
                continue
            }
            let a = tangents[i] / slopes[i], b = tangents[i + 1] / slopes[i]
            if a < 0 { tangents[i] = 0 }
            if b < 0 { tangents[i + 1] = 0 }
            let sum = a * a + b * b
            if sum > 9 {
                let scale = 3 / sum.squareRoot()
                tangents[i] = scale * a * slopes[i]
                tangents[i + 1] = scale * b * slopes[i]
            }
        }

        return (0..<(n - 1)).map { i in
            let p0 = points[i], p1 = points[i + 1]
            let h = p1.x - p0.x
            return Piece(start: p0,
                         c1: CGPoint(x: p0.x + h / 3, y: p0.y + tangents[i] * h / 3),
                         c2: CGPoint(x: p1.x - h / 3, y: p1.y - tangents[i + 1] * h / 3),
                         end: p1)
        }
    }
}

// MARK: - View

/// The history chart, drawn into a single `Canvas`. Swift Charts kept around 60 MB of GPU memory alive
/// for this small chart; one canvas needs a fraction of that and looks the same.
struct TrendCanvas: View {
    let marks: [Mark]
    let span: ChartSpan
    let language: AppLanguage
    let batteryColor: Color
    let chargingColor: Color
    @Binding var hovered: Mark?

    @Environment(\.dim) private var dim
    @State private var readoutSize: CGSize = .zero

    var body: some View {
        let end = Date.now
        let start = end - span.interval
        GeometryReader { geometry in
            let layout = TrendLayout(size: geometry.size, start: start, end: end,
                                     labelColumn: dim(24), axisRow: dim(15))
            Canvas { context, _ in draw(in: context, layout: layout) }
                .overlay(alignment: .topLeading) { readout(layout) }
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let point):
                        let date = layout.date(atX: point.x)
                        hovered = marks.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
                    case .ended:
                        hovered = nil
                    }
                }
        }
        .accessibilityElement()
        .accessibilityLabel(Copy.text("Verlauf des Ladestands", "Charge level history"))
        .accessibilityValue(marks.last.map { "\($0.p) %" } ?? "")
    }

    private func draw(in context: GraphicsContext, layout: TrendLayout) {
        let plot = layout.plot

        // Grid lines and the 0 / 50 / 100 labels on the right.
        for value in [0, 50, 100] {
            let y = layout.y(Double(value))
            var line = Path()
            line.move(to: CGPoint(x: plot.minX, y: y))
            line.addLine(to: CGPoint(x: plot.maxX, y: y))
            context.stroke(line, with: .color(.primary.opacity(0.08)), lineWidth: 0.5)
            context.draw(Text("\(value)").font(dim.number(8.5, .medium)).foregroundStyle(Color.secondary),
                         at: CGPoint(x: plot.maxX + dim(4), y: y), anchor: .leading)
        }

        // Time labels, skipped where they would collide or leave the plot.
        var taken = -CGFloat.infinity
        for tick in TrendLayout.ticks(from: layout.start, to: layout.end, span: span) {
            let centre = span == .week ? layout.x(tick + 43_200) : layout.x(tick)
            let text = context.resolve(Text(ChartAxisLabel.text(for: tick, span: span, language: language))
                .font(dim.text(8.5)).foregroundStyle(Color.secondary))
            let width = text.measure(in: CGSize(width: 200, height: 40)).width
            let left = centre - width / 2
            guard left >= plot.minX, left + width <= plot.maxX, left > taken + dim(8) else { continue }
            context.draw(text, at: CGPoint(x: centre, y: plot.maxY + dim(3)), anchor: .top)
            taken = left + width
        }

        // Area and line per stretch: blue on battery, green while charging.
        var curve = context
        curve.clip(to: Path(plot.insetBy(dx: 0, dy: -dim(3))))
        for segment in TrendSegment.split(marks, maxGap: span.maxGap) {
            let color = segment.charging ? chargingColor : batteryColor
            let points = segment.points.map { CGPoint(x: layout.x($0.date), y: layout.y(Double($0.p))) }
            let pieces = MonotoneCurve.pieces(through: points)
            guard let first = pieces.first?.start, let last = pieces.last?.end else { continue }
            var line = Path()
            line.move(to: first)
            for piece in pieces { line.addCurve(to: piece.end, control1: piece.c1, control2: piece.c2) }
            var area = line
            area.addLine(to: CGPoint(x: last.x, y: plot.maxY))
            area.addLine(to: CGPoint(x: first.x, y: plot.maxY))
            area.closeSubpath()
            curve.fill(area, with: .linearGradient(Gradient(colors: [color.opacity(0.30), color.opacity(0.02)]),
                                                   startPoint: CGPoint(x: 0, y: plot.minY),
                                                   endPoint: CGPoint(x: 0, y: plot.maxY)))
            curve.stroke(line, with: .color(color),
                         style: StrokeStyle(lineWidth: dim(2.2), lineCap: .round, lineJoin: .round))
        }

        // The pointer's sample, or the current level.
        if let hovered {
            let x = layout.x(hovered.date)
            var rule = Path()
            rule.move(to: CGPoint(x: x, y: plot.minY))
            rule.addLine(to: CGPoint(x: x, y: plot.maxY))
            context.stroke(rule, with: .color(.secondary.opacity(0.6)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            dot(in: context, at: CGPoint(x: x, y: layout.y(Double(hovered.p))), side: dim(45).squareRoot(),
                color: hovered.ac ? chargingColor : batteryColor)
        } else if let last = marks.last {
            let color = last.ac ? chargingColor : batteryColor
            let point = CGPoint(x: layout.x(last.date), y: layout.y(Double(last.p)))
            dot(in: context, at: point, side: dim(150).squareRoot(), color: color.opacity(0.22))
            dot(in: context, at: point, side: dim(40).squareRoot(), color: color)
        }
    }

    private func dot(in context: GraphicsContext, at centre: CGPoint, side: CGFloat, color: Color) {
        let rect = CGRect(x: centre.x - side / 2, y: centre.y - side / 2, width: side, height: side)
        context.fill(Path(ellipseIn: rect), with: .color(color))
    }

    @ViewBuilder private func readout(_ layout: TrendLayout) -> some View {
        if let hovered {
            let plot = layout.plot
            let x = min(max(layout.x(hovered.date) - readoutSize.width / 2, plot.minX), max(plot.maxX - readoutSize.width, plot.minX))
            // Opposite the point, so the label never hides it: high levels read at the bottom, low ones at the top.
            let y = hovered.p > 55 ? plot.maxY - readoutSize.height - dim(2) : plot.minY
            Text(TrendReadout.text(level: hovered.p, at: hovered.date, span: span, language: language))
                .font(dim.number(9.5, .semibold))
                .padding(.horizontal, dim(7)).padding(.vertical, dim(3))
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().stroke(.primary.opacity(0.1), lineWidth: 0.5))
                .fixedSize()
                .onGeometryChange(for: CGSize.self) { $0.size } action: { readoutSize = $0 }
                .offset(x: x, y: y)
                .allowsHitTesting(false)
        }
    }
}
