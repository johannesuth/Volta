import Foundation
import SwiftUI
import UserNotifications

/// Pure decision logic: which triggers does the step `before → now` cross?
enum Crossing {
    static func fired(before: PowerSnapshot?, now: PowerSnapshot, triggers: [Trigger]) -> [Trigger] {
        guard now.hasPack else { return [] }
        let live = triggers.filter(\.active)
        let downs = live.filter { $0.direction == .down }
        let ups = live.filter { $0.direction == .up }

        // Draining: report only the deepest threshold that was passed in this step.
        var result: [Trigger] = []
        if !now.onMains {
            let start = (before?.onMains == false) ? before!.level : 101
            let passed = downs.filter { start > $0.level && now.level <= $0.level }
            if let deepest = passed.min(by: { $0.level < $1.level }) { result.append(deepest) }
        }
        // Filling: report every ceiling crossed upward while on mains.
        if now.onMains, let b = before, b.onMains {
            result += ups.filter { b.level < $0.level && now.level >= $0.level }
        }
        return result
    }
}

/// Listens to power ticks and accessory scans and turns crossings into sound + light.
@MainActor
final class Sentinel {
    static let shared = Sentinel()
    private var tokens: [NSObjectProtocol] = []
    private var lastFire: [UUID: Date] = [:]
    private var gadgetBefore: [String: Int] = [:]

    private init() {}

    func arm() {
        guard tokens.isEmpty else { return }
        tokens.append(NotificationCenter.default.addObserver(forName: .powerTick, object: nil, queue: .main) { note in
            guard let tick = note.object as? PowerTick else { return }
            MainActor.assumeIsolated { Sentinel.shared.handle(tick) }
        })
        tokens.append(NotificationCenter.default.addObserver(forName: .gadgetsScanned, object: nil, queue: .main) { note in
            guard let list = note.object as? [Gadget] else { return }
            MainActor.assumeIsolated { Sentinel.shared.handle(list) }
        })
        if ConfigStore.shared.c.bannerAlso {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    private func handle(_ tick: PowerTick) {
        let cfg = ConfigStore.shared.c
        if let b = tick.before, b.hasPack, b.onMains != tick.now.onMains, cfg.plugTone {
            Chime.ring(tick.now.onMains ? "Morse" : "Frog", gain: 0.45)
        }
        let cooldown = cfg.cooldownMinutes * 60
        for t in Crossing.fired(before: tick.before, now: tick.now, triggers: cfg.triggers) {
            if let last = lastFire[t.id], Date.now.timeIntervalSince(last) < cooldown { continue }
            lastFire[t.id] = .now
            stage(t, level: tick.now.level, snapshot: tick.now, preview: false)
        }
    }

    private func handle(_ list: [Gadget]) {
        let floor = ConfigStore.shared.c.gadgetFloor
        let hidden = Set(ConfigStore.shared.c.hiddenGadgets)
        for g in list where g.connected && !hidden.contains(g.id) {
            guard let level = g.lowest else { continue }
            defer { gadgetBefore[g.id] = level }
            guard floor > 0, let old = gadgetBefore[g.id], old > floor, level <= floor else { continue }
            Chime.ring("Pop")
            Spotlight.shared.present(Notice(
                headline: "\(g.name) · \(level) %",
                detail: Copy.text("Der Akku des Zubehörs ist fast leer.", "This accessory is running low."),
                symbol: g.family.sfSymbol,
                tint: level <= 10 ? Hue.alarm : (level <= 20 ? Hue.warn : Hue.accent),
                fraction: Double(level) / 100,
                aura: false, card: true, lingers: false, urgent: false))
            if ConfigStore.shared.c.bannerAlso { banner(g.name, Copy.text("Akku bei \(level) %", "Battery at \(level)%")) }
        }
    }

    /// Shows a trigger. `preview` is used by Settings' play buttons.
    func stage(_ t: Trigger, level: Int, snapshot s: PowerSnapshot, preview: Bool) {
        let cfg = ConfigStore.shared.c
        Chime.ring(t.tone, force: preview)
        let urgent = t.direction == .down && level <= 10
        let detail: String
        switch t.direction {
        case .down:
            detail = s.minutesToEmpty.map { Copy.text("Der Akku hält noch etwa \(Telemetry.span($0)). Halte das Netzteil bereit.",
                                                       "About \(Telemetry.span($0)) left. Keep your charger handy.") }
                ?? (urgent ? Copy.text("Schließe jetzt das Netzteil an.", "Connect your charger now.")
                           : Copy.text("Jetzt ist ein guter Zeitpunkt, das Netzteil anzuschließen.", "Now is a good time to connect your charger."))
        case .up:
            detail = level >= 100 ? Copy.text("Akku voll. Du kannst das Netzteil abziehen.", "The battery is full. You can unplug the charger.")
                                  : Copy.text("Ladeziel erreicht. Das schont den Akku.", "Charge limit reached. This helps protect the battery.")
        }
        let notice = Notice(
            headline: t.direction == .down ? Copy.text("Noch \(level) %", "\(level)% remaining")
                                            : Copy.text("Auf \(level) % geladen", "Charged to \(level)%"),
            detail: detail,
            symbol: t.direction == .down ? "battery.25percent" : "bolt.fill",
            tint: t.direction == .up ? Hue.good : (level <= 10 ? Hue.alarm : (level <= 20 ? Hue.warn : Hue.accent)),
            fraction: Double(level) / 100,
            aura: t.presentation.wantsAura, card: t.presentation.wantsCard,
            lingers: t.lingers, urgent: urgent)
        if t.presentation == .banner || cfg.bannerAlso { banner(notice.headline, notice.detail) }
        if t.presentation != .banner { Spotlight.shared.present(notice) }
    }

    private func banner(_ title: String, _ body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
