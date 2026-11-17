import AppKit
import SwiftUI

/// Borderless key-capable panel hosting the dropdown.
final class DropWindow: NSPanel {
    var onEscape: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { onEscape?() }
}

/// Owns the status item and the dropdown window.
@MainActor
final class MenuBarPresence: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var window: DropWindow?
    private var host: NSHostingView<AnyView>?
    private var leases: [Telemetry.Lease] = []
    private var refreshTokens: [NSObjectProtocol] = []
    private var repaintWorkItem: DispatchWorkItem?
    private var repaintGate = StatusIconRefreshGate(minimumInterval: 0.2)
    private var anchor: (midX: CGFloat, top: CGFloat, screen: NSRect)?
    private var resignToken: NSObjectProtocol?
    private var barAppearance: NSKeyValueObservation?
    var showPreferences: () -> Void = {}

    override init() {
        super.init()
        item.behavior = []
        guard let button = item.button else { return }
        button.target = self
        button.action = #selector(pressed)
        button.sendAction(on: [.leftMouseDown, .rightMouseDown])
        refreshTokens = [
            NotificationCenter.default.addObserver(forName: .powerTick, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scheduleRepaint() }
            },
            NotificationCenter.default.addObserver(forName: .gadgetsScanned, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scheduleRepaint() }
            },
            NotificationCenter.default.addObserver(forName: .configChanged, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scheduleRepaint() }
            },
        ]
        barAppearance = button.observe(\.effectiveAppearance) { [weak self] _, _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.scheduleRepaint() } }
        }
        repaint()
    }

    // MARK: Icon

    private func repaint() {
        repaintGate.recordRefresh(at: .now)
        let t = Telemetry.shared
        let snapshot = t.now
        let cfg = ConfigStore.shared.c
        let badges = cfg.pinned.compactMap { id -> GlyphBadge? in
            guard let g = GadgetHub.shared.all.first(where: { $0.id == id }), g.connected else { return nil }
            return GlyphBadge(symbol: g.family.sfSymbol, level: g.lowest)
        }
        let dark = item.button?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let image = GlyphPainter.image(snapshot: snapshot, clock: t.compactTime, cfg: cfg, darkBar: dark, badges: badges)
        if snapshot.hasPack {
            item.button?.image = image
        } else {
            let plug = NSImage(systemSymbolName: "powerplug.portrait.fill", accessibilityDescription: "Volta")
            plug?.isTemplate = true
            item.button?.image = plug
        }
        item.button?.setAccessibilityLabel(Copy.text("Volta – \(snapshot.level) Prozent, \(t.headline)",
                                                      "Volta — \(snapshot.level) percent, \(t.headline)"))
    }

    private func scheduleRepaint() {
        guard repaintWorkItem == nil else { return }
        let delay = repaintGate.delayUntilAllowed(at: .now)
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.repaintWorkItem = nil
            self.repaint()
        }
        repaintWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    // MARK: Interaction

    @objc private func pressed() {
        if NSApp.currentEvent?.type == .rightMouseDown {
            let menu = NSMenu()
            menu.addItem(withTitle: Copy.text("Dashboard", "Dashboard"), action: #selector(openFromMenu), keyEquivalent: "").target = self
            menu.addItem(withTitle: Copy.text("Einstellungen …", "Settings …"), action: #selector(prefsFromMenu), keyEquivalent: ",").target = self
            menu.addItem(.separator())
            menu.addItem(withTitle: Copy.text("Volta beenden", "Quit Volta"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            if let button = item.button {
                menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 5), in: button)
            }
            return
        }
        toggle()
    }

    @objc private func openFromMenu() { open() }
    @objc private func prefsFromMenu() { showPreferences() }

    var isOpen: Bool { window?.isVisible == true }

    func toggle() { isOpen ? close() : open() }

    func open() {
        guard !isOpen, let button = item.button, let bw = button.window else { return }
        let rect = bw.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = bw.screen ?? NSScreen.main!
        anchor = (rect.midX, rect.minY - 5, screen.visibleFrame)

        if window == nil { buildWindow() }
        guard let window else { return }
        window.appearance = ConfigStore.shared.c.look.appearance
        leases = [Telemetry.shared.lease(), GadgetHub.shared.boost(), PowerLedger.shared.watch()]
        Telemetry.shared.pull()

        place(size: host?.fittingSize ?? NSSize(width: 392, height: 560))
        window.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { $0.duration = 0.16; window.animator().alphaValue = 1 }

        // Arm "close when focus leaves" a beat later, so activation hand-offs don't close it instantly.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard let self, self.isOpen, self.resignToken == nil else { return }
            self.resignToken = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, !ConfigStore.shared.c.stickyDropdown else { return }
                    self.close()
                }
            }
        }
    }

    func close() {
        guard let window, window.isVisible else { return }
        if let resignToken { NotificationCenter.default.removeObserver(resignToken) }
        resignToken = nil
        leases.removeAll()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.12; window.animator().alphaValue = 0 } completionHandler: {
            window.orderOut(nil)
        }
    }

    private func buildWindow() {
        let w = DropWindow(contentRect: NSRect(x: 0, y: 0, width: 392, height: 560),
                           styleMask: [.borderless, .fullSizeContentView], backing: .buffered, defer: true)
        w.backgroundColor = .clear
        w.isOpaque = false
        w.hasShadow = true
        w.level = .popUpMenu
        w.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient]
        w.isReleasedWhenClosed = false
        w.onEscape = { [weak self] in self?.close() }

        let root = DropdownRoot(
            onSize: { [weak self] size in self?.place(size: size) },
            openPreferences: { [weak self] in self?.close(); self?.showPreferences() },
            dismiss: { [weak self] in self?.close() })
        let hosting = NSHostingView(rootView: AnyView(root))
        hosting.sizingOptions = []
        w.contentView = hosting
        host = hosting
        window = w
    }

    /// Keeps the dropdown hanging from the menu bar, centred on the icon, inside the screen.
    private func place(size: CGSize) {
        guard let window, let a = anchor, size.width > 10, size.height > 10 else { return }
        var x = a.midX - size.width / 2
        x = min(max(x, a.screen.minX + 6), a.screen.maxX - size.width - 6)
        let frame = NSRect(x: x.rounded(), y: (a.top - size.height).rounded(), width: size.width.rounded(), height: size.height.rounded())
        if window.frame != frame { window.setFrame(frame, display: true) }
    }
}
