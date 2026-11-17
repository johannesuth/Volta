// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import Foundation
import VoltaLanguageCore
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
        if ConfigStore.shared.c.alerts.style == .banner { requestNotificationPermission() }
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func handle(_ tick: PowerTick) {
        let cfg = ConfigStore.shared.c
        if let b = tick.before, b.hasPack, b.onMains != tick.now.onMains, cfg.plugTone {
            Chime.ring(tick.now.onMains ? "Morse" : "Frog", gain: 0.45)
        }
        let cooldown: TimeInterval = 10 * 60
        for t in Crossing.fired(before: tick.before, now: tick.now, triggers: cfg.alerts.triggers) {
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
            Chime.ring(ConfigStore.shared.c.alerts.tone)
            if ConfigStore.shared.c.alerts.style == .banner {
                banner(g.name, Copy.text("Akku bei \(level) %", "Battery at \(level)%"))
                continue
            }
            let alerts = ConfigStore.shared.c.alerts
            Spotlight.shared.present(Notice(
                headline: "\(g.name) · \(level) %",
                detail: Copy.text("Der Akku des Zubehörs ist fast leer.", "This accessory is running low."),
                symbol: g.family.sfSymbol,
                tint: Hue.alert(alerts.color.swatch(direction: .down, level: level)),
                fraction: Double(level) / 100,
                aura: alerts.style.wantsAura, card: true, seconds: AlertPlan.showSeconds, urgent: false))
        }
    }

    /// Shows a trigger. `preview` is used by Settings' test button.
    func stage(_ t: Trigger, level: Int, snapshot s: PowerSnapshot, preview: Bool) {
        Chime.ring(t.tone, force: preview)
        let notice = Self.notice(for: t, level: level, snapshot: s, plan: ConfigStore.shared.c.alerts)
        if t.presentation == .banner { banner(notice.headline, notice.detail) } else { Spotlight.shared.present(notice) }
    }

    /// The card's content and look for a trigger; also used for the live preview in Settings.
    static func notice(for t: Trigger, level: Int, snapshot s: PowerSnapshot, plan: AlertPlan) -> Notice {
        let urgent = t.direction == .down && level <= 10
        let detail: String
        switch t.direction {
        case .down:
            detail = lowDetail(minutesLeft: s.minutesToEmpty, urgent: urgent, language: Copy.language)
        case .up:
            detail = level >= 100 ? Copy.text("Akku voll. Du kannst das Netzteil abziehen.", "The battery is full. You can unplug the charger.")
                                  : Copy.text("Ladeziel erreicht. Das schont den Akku.", "Charge limit reached. This helps protect the battery.")
        }
        return Notice(
            headline: t.direction == .down ? Copy.text("Noch \(level) %", "\(level)% remaining")
                                            : Copy.text("Auf \(level) % geladen", "Charged to \(level)%"),
            detail: detail,
            symbol: t.direction == .down ? (urgent ? "battery.0percent" : "battery.25percent") : "bolt.fill",
            tint: Hue.alert(plan.color.swatch(direction: t.direction, level: level)),
            fraction: Double(level) / 100,
            aura: t.presentation.wantsAura, card: t.presentation.wantsCard,
            seconds: AlertPlan.showSeconds, urgent: urgent)
    }

    /// The second line of a low-battery alert. German time spans end with a period ("42 Min."), so the
    /// sentence continues instead of ending right after it.
    nonisolated static func lowDetail(minutesLeft: Int?, urgent: Bool, language: AppLanguage) -> String {
        if let minutes = minutesLeft {
            let span = Telemetry.span(minutes, language: language)
            return language.localized(german: "Noch etwa \(span) Laufzeit – halte das Netzteil bereit.",
                                      english: "About \(span) left. Keep your charger handy.")
        }
        return urgent
            ? language.localized(german: "Schließe jetzt das Netzteil an.", english: "Connect your charger now.")
            : language.localized(german: "Jetzt ist ein guter Zeitpunkt, das Netzteil anzuschließen.",
                                 english: "Now is a good time to connect your charger.")
    }

    /// A real macOS notification (banner and Notification Center). Asks for permission first if needed.
    private func banner(_ title: String, _ body: String) {
        Task {
            let center = UNUserNotificationCenter.current()
            if await center.notificationSettings().authorizationStatus == .notDetermined {
                guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
            }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.threadIdentifier = "battery"
            try? await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }
}
