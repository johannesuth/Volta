// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import AppKit
import SwiftUI

/// Borderless key-capable panel hosting the dropdown.
final class DropWindow: NSPanel {
    var onEscape: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { onEscape?() }

    static func make() -> DropWindow {
        let w = DropWindow(contentRect: NSRect(x: 0, y: 0, width: 392, height: 560),
                           styleMask: [.borderless, .fullSizeContentView], backing: .buffered, defer: true)
        w.backgroundColor = .clear
        w.isOpaque = false
        w.hasShadow = true
        w.level = .popUpMenu
        w.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient]
        w.isReleasedWhenClosed = false
        // Panels hide themselves when the app loses focus by default; a pinned dashboard must stay.
        w.hidesOnDeactivate = false
        return w
    }
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
    /// What the menu bar currently shows; a repaint that would draw the same thing is skipped.
    private var shownSignature: String?
    private var shownTip: String?
    private var shownDark: Bool?
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
        // Setting an image makes macOS touch the button's appearance; only a real light/dark switch
        // may lead to a repaint, otherwise the two keep triggering each other.
        barAppearance = button.observe(\.effectiveAppearance) { [weak self] _, _ in
            DispatchQueue.main.async { MainActor.assumeIsolated {
                guard let self, self.barIsDark != self.shownDark else { return }
                self.scheduleRepaint()
            } }
        }
        repaint()
    }

    // MARK: Icon

    private var barIsDark: Bool {
        item.button?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private func repaint() {
        repaintGate.recordRefresh(at: .now)
        let t = Telemetry.shared
        let snapshot = t.now
        let cfg = ConfigStore.shared.c
        let badges = cfg.pinned.compactMap { id -> GlyphBadge? in
            guard let g = GadgetHub.shared.all.first(where: { $0.id == id }), g.connected else { return nil }
            return GlyphBadge(symbol: g.family.sfSymbol, level: g.lowest)
        }
        let dark = barIsDark
        shownDark = dark
        if snapshot.hasPack {
            let drawing = GlyphPainter.drawing(snapshot: snapshot, clock: t.compactTime, cfg: cfg, darkBar: dark, badges: badges)
            let signature = drawing.signature
            if signature != shownSignature {
                item.button?.image = GlyphPainter.image(for: drawing)
                shownSignature = signature
            }
        } else if shownSignature != "plug" {
            let plug = NSImage(systemSymbolName: "powerplug.portrait.fill", accessibilityDescription: "Volta")
            plug?.isTemplate = true
            item.button?.image = plug
            shownSignature = "plug"
        }
        let tip = snapshot.hasPack ? "\(snapshot.level) % · \(t.headline)" : t.headline
        if tip != shownTip {
            item.button?.setAccessibilityLabel(Copy.text("Volta – \(snapshot.level) Prozent, \(t.headline)",
                                                          "Volta — \(snapshot.level) percent, \(t.headline)"))
            item.button?.toolTip = tip
            shownTip = tip
        }
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
        // App energy and accessory scans are leased by their dashboard sections while those are visible.
        leases = [Telemetry.shared.lease()]
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
        NSAnimationContext.runAnimationGroup { $0.duration = 0.12; window.animator().alphaValue = 0 } completionHandler: { [weak self] in
            window.orderOut(nil)
            MainActor.assumeIsolated { self?.release(window) }
        }
    }

    /// A closed dashboard keeps nothing alive: no SwiftUI views that react to new samples, no chart, no memory.
    /// Building it again on the next click takes a few milliseconds.
    private func release(_ closed: DropWindow) {
        guard window === closed, !closed.isVisible else { return }
        closed.contentView = nil
        host = nil
        window = nil
    }

    private func buildWindow() {
        let w = DropWindow.make()
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
        // Never let the panel run off the screen: fold the section that has been open longest.
        if size.height > a.top - a.screen.minY - 6 {
            var expansion = ConfigStore.shared.c.expansion
            if expansion.collapseOldest() { ConfigStore.shared.c.expansion = expansion }
        }
        var x = a.midX - size.width / 2
        x = min(max(x, a.screen.minX + 6), a.screen.maxX - size.width - 6)
        let frame = NSRect(x: x.rounded(), y: (a.top - size.height).rounded(), width: size.width.rounded(), height: size.height.rounded())
        if window.frame != frame { window.setFrame(frame, display: true) }
    }
}
