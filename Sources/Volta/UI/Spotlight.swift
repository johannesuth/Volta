import AppKit
import QuartzCore
import SwiftUI

struct Notice {
    var headline: String
    var detail: String
    var symbol: String
    var tint: Color
    var fraction: Double
    var aura: Bool
    var card: Bool
    var lingers: Bool
    var urgent: Bool
}

/// Screen-edge aura drawn with Core Animation: a slowly spinning conic gradient,
/// masked to the display outline and softened by Core Image blur on parent layers.
final class AuraLayerView: NSView {
    init(frame: NSRect, tint: NSColor, gain: Double) {
        super.init(frame: frame)
        wantsLayer = true
        layerUsesCoreImageFilters = true
        guard let root = layer else { return }
        // One hue: bright and faint passages chase each other around the edge.
        let partner = tint.blended(withFraction: 0.45, of: .systemPink) ?? tint
        let cg = [tint, partner.withAlphaComponent(0.35), tint.withAlphaComponent(0.8), partner.withAlphaComponent(0.2), tint].map(\.cgColor)
        let outline = CGPath(roundedRect: bounds, cornerWidth: 12, cornerHeight: 12, transform: nil)
        let diagonal = hypot(bounds.width, bounds.height)

        for (band, softness, strength) in [(70.0 * gain, 38.0 * gain, 0.55), (14.0 * gain, 7.0, 0.7), (1.5, 0.0, 0.8)] {
            let halo = CALayer()
            halo.frame = bounds
            if softness > 0, let blur = CIFilter(name: "CIGaussianBlur", parameters: [kCIInputRadiusKey: softness]) {
                halo.filters = [blur]
            }
            halo.opacity = Float(strength)

            let clip = CALayer()
            clip.frame = bounds
            let mask = CAShapeLayer()
            mask.frame = bounds
            mask.path = outline
            mask.fillColor = nil
            mask.strokeColor = NSColor.black.cgColor
            mask.lineWidth = band * 2          // the outer half falls off-screen
            clip.mask = mask

            let sweep = CAGradientLayer()
            sweep.type = .conic
            sweep.colors = cg
            sweep.startPoint = CGPoint(x: 0.5, y: 0.5)
            sweep.endPoint = CGPoint(x: 0.5, y: 0)
            sweep.bounds = CGRect(x: 0, y: 0, width: diagonal, height: diagonal)
            sweep.position = CGPoint(x: bounds.midX, y: bounds.midY)
            let spin = CABasicAnimation(keyPath: "transform.rotation.z")
            spin.fromValue = 0
            spin.toValue = Double.pi * 2
            spin.duration = 12
            spin.repeatCount = .infinity
            sweep.add(spin, forKey: "spin")

            clip.addSublayer(sweep)
            halo.addSublayer(clip)
            root.addSublayer(halo)
        }

        let breathe = CABasicAnimation(keyPath: "opacity")
        breathe.fromValue = 1.0
        breathe.toValue = 0.7
        breathe.duration = 2.2
        breathe.autoreverses = true
        breathe.repeatCount = .infinity
        breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        root.add(breathe, forKey: "breathe")
    }

    required init?(coder: NSCoder) { nil }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

final class ClickableHost<V: View>: NSHostingView<V> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Presents notices: optional aura on the pointer's display plus a glass card.
@MainActor
final class Spotlight {
    static let shared = Spotlight()

    private var auraWindow: NSWindow?
    private var cardWindow: NSPanel?
    private var expiry: Task<Void, Never>?

    private var screen: NSScreen {
        let p = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(p) } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    func present(_ n: Notice) {
        dismiss(fade: false)
        let display = screen

        if n.aura {
            let w = NSWindow(contentRect: display.frame, styleMask: .borderless, backing: .buffered, defer: false)
            w.setFrame(display.frame, display: false)
            w.backgroundColor = .clear
            w.isOpaque = false
            w.hasShadow = false
            w.ignoresMouseEvents = true
            w.level = .screenSaver
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            w.isReleasedWhenClosed = false
            w.contentView = AuraLayerView(frame: NSRect(origin: .zero, size: display.frame.size),
                                          tint: NSColor(n.tint), gain: 0.55)
            w.alphaValue = 0
            w.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { $0.duration = 0.6; w.animator().alphaValue = 1 }
            auraWindow = w
        }

        if n.card {
            let size = NSSize(width: 440, height: 160)
            let vf = display.visibleFrame
            let placement: CardPlacement = n.urgent ? .middle : .upper
            let origin: NSPoint = switch placement {
            case .middle: NSPoint(x: vf.midX - size.width / 2, y: vf.midY - size.height / 2 + 60)
            case .lowerRight: NSPoint(x: vf.maxX - size.width - 12, y: vf.minY + 12)
            default: NSPoint(x: vf.midX - size.width / 2, y: vf.maxY - size.height)
            }
            let panel = NSPanel(contentRect: NSRect(origin: origin, size: size),
                                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.isReleasedWhenClosed = false
            let host = ClickableHost(rootView: NoticeCard(notice: n) { [weak self] in self?.dismiss() })
            host.frame = NSRect(origin: .zero, size: size)
            panel.contentView = host
            panel.orderFrontRegardless()
            cardWindow = panel
        }

        let seconds: Double = n.lingers ? 60 : 8
        expiry = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    func dismiss(fade: Bool = true) {
        expiry?.cancel()
        let gone = [auraWindow, cardWindow].compactMap { $0 }
        auraWindow = nil
        cardWindow = nil
        guard fade else { gone.forEach { $0.orderOut(nil) }; return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.4
            gone.forEach { $0.animator().alphaValue = 0 }
        } completionHandler: {
            gone.forEach { $0.orderOut(nil) }
        }
    }
}

extension Look {
    var appearance: NSAppearance? {
        switch self {
        case .night: NSAppearance(named: .darkAqua)
        case .day: NSAppearance(named: .aqua)
        case .auto: nil
        }
    }
}

/// The glass card shown with a notice: icon, two lines of text, one thin progress ring.
struct NoticeCard: View {
    let notice: Notice
    let close: () -> Void
    @State private var shown = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().stroke(.primary.opacity(0.1), lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: shown ? notice.fraction : 0)
                    .stroke(notice.tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: notice.symbol)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(notice.tint)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(notice.headline).font(.system(size: 15, weight: .semibold))
                Text(notice.detail).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 4)
            Button(action: close) {
                Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(width: 400, height: 76)
        .glassPlate(radius: 20)
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.primary.opacity(0.08), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
        .frame(width: 440, height: 160)
        .offset(y: shown ? 0 : -10)
        .opacity(shown ? 1 : 0)
        .onAppear { withAnimation(.smooth(duration: 0.35)) { shown = true } }
        .onTapGesture(perform: close)
    }
}
