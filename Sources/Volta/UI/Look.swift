// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import SwiftUI
import AppKit

// MARK: - Colour

/// A restrained, desaturated palette. The interface shares one accent; signal
/// colours remain for battery states that need attention.
enum Hue {
    static let sky = Color(red: 0.42, green: 0.63, blue: 0.82)
    static let iris = Color(red: 0.52, green: 0.56, blue: 0.77)
    static let lagoon = Color(red: 0.36, green: 0.66, blue: 0.70)
    static let mint = Color(red: 0.41, green: 0.69, blue: 0.55)
    static let amber = Color(red: 0.83, green: 0.66, blue: 0.39)
    static let coral = Color(red: 0.78, green: 0.48, blue: 0.45)
    static let blush = Color(red: 0.74, green: 0.54, blue: 0.64)

    static let good = mint
    static let warn = amber
    static let alarm = coral

    static var accent: Color { duo(ConfigStore.shared.c.accent).0 }
    static var accentDuo: (Color, Color) { duo(ConfigStore.shared.c.accent) }

    static func swatch(_ a: Accent) -> Color { duo(a).0 }

    static func duo(_ a: Accent) -> (Color, Color) {
        switch a {
        case .graphite: (Color(white: 0.62), Color(white: 0.42))
        case .system: (.accentColor, .accentColor.opacity(0.65))
        case .blue: (sky, iris)
        case .teal: (lagoon, mint)
        case .mint: (mint, lagoon)
        case .indigo: (iris, blush)
        case .amber: (amber, coral)
        case .rose: (blush, iris)
        }
    }

    /// Two-stop colour for the Mac's own battery state.
    static func stateDuo(_ mode: FlowMode, level: Int) -> (Color, Color) {
        switch mode {
        case .filling, .topped: (mint, lagoon)
        case .deficit: (amber, coral)
        case .draining where level <= 10: (coral, blush)
        case .draining where level <= 20: (amber, coral)
        default: accentDuo
        }
    }

    static func state(_ mode: FlowMode, level: Int) -> Color { stateDuo(mode, level: level).0 }

    /// Colour for any battery level (accessories, alerts).
    static func level(_ value: Int?) -> Color {
        guard let value else { return .secondary }
        return value <= 10 ? coral : (value <= 20 ? amber : mint)
    }

    /// Colour for an alert card, glow and preview.
    static func alert(_ swatch: AlertSwatch) -> Color {
        switch swatch {
        case .accent: accent
        case .good: good
        case .warn: warn
        case .alarm: alarm
        case .blue: sky
        case .teal: lagoon
        case .mint: mint
        case .indigo: iris
        case .amber: amber
        case .rose: blush
        }
    }

    /// Keep cards visually calm; reserve state colours for data and alerts.
    static func of(_ kind: TileKind) -> Color { accent }
}

// MARK: - Scale

/// Fixed-size layout metrics shared across the dropdown.
struct Dim {
    var k: CGFloat = 1
    /// Type is set about 11 % larger than the layout grid, so text reads comfortably while the panel keeps its size.
    var type: CGFloat = 1.11
    func callAsFunction(_ v: CGFloat) -> CGFloat { v * k }
    func pointSize(_ size: CGFloat) -> CGFloat { size * k * type }
    /// Regular text is drawn one step heavier (medium), which reads better on the translucent panel.
    func text(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: pointSize(size), weight: weight == .regular ? .medium : weight)
    }
    func number(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: pointSize(size), weight: weight, design: .rounded).monospacedDigit()
    }
}

extension EnvironmentValues {
    @Entry var dim = Dim()
    @Entry var tileExpansion: Binding<TileExpansion> = .constant(TileExpansion())
}

// MARK: - Building blocks

/// A section of the dropdown: coloured icon + caption, content, and a faint wash of its hue.
struct Tile<Content: View>: View {
    @Environment(\.dim) private var dim
    @Environment(\.tileExpansion) private var expansion
    let kind: TileKind?
    let tint: Color
    let trailing: AnyView?
    let content: Content

    init(kind: TileKind? = nil, tint: Color? = nil, trailing: AnyView? = nil, @ViewBuilder content: () -> Content) {
        self.kind = kind
        self.tint = tint ?? kind.map(Hue.of) ?? Hue.accent
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: dim(14), style: .continuous)
        let expanded = kind.map { expansion.wrappedValue.contains($0) } ?? true
        VStack(alignment: .leading, spacing: dim(9)) {
            if let kind {
                HStack(spacing: dim(6)) {
                    Button {
                        var next = expansion.wrappedValue
                        next.toggle(kind)
                        expansion.wrappedValue = next
                    } label: {
                        HStack(spacing: dim(7)) {
                            Image(systemName: kind.icon)
                                .font(dim.text(10, .medium))
                                .foregroundStyle(tint)
                                .frame(width: dim(16))
                            Text(kind.title)
                                .font(dim.text(11.5, .semibold))
                                .foregroundStyle(.primary.opacity(0.85))
                            Image(systemName: expanded ? "chevron.down" : "chevron.right")
                                .font(dim.text(8, .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 0)
                    trailing
                }
            }
            if expanded { content.transition(.opacity) }
        }
        .padding(dim(12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(.primary.opacity(0.035)))
        .overlay(shape.stroke(.primary.opacity(0.065), lineWidth: 0.5))
        .animation(.snappy(duration: 0.18), value: expanded)
    }
}

/// Inline key figure: small coloured icon + caption over a value.
struct Figure: View {
    @Environment(\.dim) private var dim
    var caption: String
    var value: String
    var icon: String? = nil
    var tint: Color = .secondary
    var valueTint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: dim(2)) {
            HStack(spacing: dim(4)) {
                if let icon { Image(systemName: icon).font(dim.text(9, .semibold)).foregroundStyle(tint) }
                Text(caption).font(dim.text(10)).foregroundStyle(.secondary)
            }
            Text(value).font(dim.number(13.5)).foregroundStyle(valueTint)
                .contentTransition(.numericText())
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Thin capsule meter with a two-stop gradient.
struct Meter: View {
    var fraction: Double
    var colors: [Color]
    var thickness: CGFloat

    init(fraction: Double, colors: [Color], thickness: CGFloat) {
        self.fraction = fraction
        self.colors = colors
        self.thickness = thickness
    }

    init(fraction: Double, tint: Color, thickness: CGFloat) {
        self.init(fraction: fraction, colors: [tint, tint.opacity(0.75)], thickness: thickness)
    }

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.09))
                Capsule()
                    .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(thickness, g.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: thickness)
        .animation(.smooth(duration: 0.5), value: fraction)
    }
}

struct Backdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .popover
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {}
}

extension View {
    /// Liquid Glass where available, a vibrancy view elsewhere. `shade` darkens (or lightens) the plate.
    @ViewBuilder func glassPlate(radius: CGFloat, shade: Double = 0.35) -> some View {
        if #available(macOS 26.0, *) {
            background(Color(nsColor: .windowBackgroundColor).opacity(shade), in: .rect(cornerRadius: radius))
                .glassEffect(.regular, in: .rect(cornerRadius: radius))
        } else {
            background(Color(nsColor: .windowBackgroundColor).opacity(shade), in: .rect(cornerRadius: radius))
                .background(Backdrop().clipShape(.rect(cornerRadius: radius)))
        }
    }
}
