import Foundation
import Observation

extension Notification.Name {
    /// object: `PowerTick` — posted after every fresh power sample.
    static let powerTick = Notification.Name("volta.powerTick")
    /// object: `[Gadget]` — posted after every accessory scan.
    static let gadgetsScanned = Notification.Name("volta.gadgetsScanned")
    /// Posted after user-visible configuration changes.
    static let configChanged = Notification.Name("volta.configChanged")
}

struct PowerTick {
    let before: PowerSnapshot?
    let now: PowerSnapshot
}

/// Keeps the most recent `PowerSnapshot` and decides how often to sample.
/// While any `Lease` is alive (the dropdown is open) sampling runs at ~1.5 s.
@Observable @MainActor
final class Telemetry {
    static let shared = Telemetry()

    private(set) var now = PowerSnapshot()
    /// Rolling average of the last few pack-power readings for calm numbers.
    private(set) var calmPackWatts = 0.0

    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var leases = 0
    @ObservationIgnored private var recentPack: [Double] = []
    @ObservationIgnored private var recentCurrent: [(Date, Double)] = []
    @ObservationIgnored private var watcher: PackWatcher?
    @ObservationIgnored private var lastPull = Date.distantPast

    final class Lease {
        private let release: () -> Void
        init(_ release: @escaping () -> Void) { self.release = release }
        deinit { release() }
    }

    private init() {
        pull()
        watcher = PackWatcher { [weak self] in
            MainActor.assumeIsolated {
                guard let self, Date.now.timeIntervalSince(self.lastPull) > 0.8 else { return }
                self.pull()
            }
        }
        NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.pull() }
        }
        restartLoop()
    }

    func lease() -> Lease {
        leases += 1
        restartLoop()
        return Lease { [weak self] in
            DispatchQueue.main.async { MainActor.assumeIsolated {
                guard let self else { return }
                self.leases -= 1
                self.restartLoop()
            } }
        }
    }

    private var cadence: Duration {
        if leases > 0 { return .milliseconds(1500) }
        var seconds = ConfigStore.shared.c.pollSeconds
        if !now.onMains && now.level <= 12 { seconds = min(seconds, 8) }
        return .seconds(seconds)
    }

    private func restartLoop() {
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let pause = self?.cadence else { return }
                try? await Task.sleep(for: pause)
                guard !Task.isCancelled else { return }
                self?.pull()
            }
        }
    }

    func pull() {
        lastPull = .now
        var fresh = PowerProbe.sample(previous: now.hasPack ? now : nil)
        fresh.deficit = judgeDeficit(fresh)

        recentPack.append(fresh.packWatts)
        if recentPack.count > 4 { recentPack.removeFirst(recentPack.count - 4) }
        calmPackWatts = recentPack.reduce(0, +) / Double(recentPack.count)

        let before = now.hasPack || now.taken != .distantPast ? now : nil
        now = fresh
        NotificationCenter.default.post(name: .powerTick, object: PowerTick(before: before, now: fresh))
    }

    /// Mains connected, yet the median current over the last ~15 s is clearly outbound.
    private func judgeDeficit(_ s: PowerSnapshot) -> Bool {
        guard s.onMains else { recentCurrent.removeAll(); return false }
        recentCurrent.append((s.taken, s.milliamps))
        recentCurrent.removeAll { s.taken.timeIntervalSince($0.0) > 15 }
        guard let first = recentCurrent.first, s.taken.timeIntervalSince(first.0) >= 10 || recentCurrent.count >= 6 else {
            return now.deficit
        }
        let sorted = recentCurrent.map(\.1).sorted()
        return sorted[sorted.count / 2] < -180
    }

    // MARK: Wording

    static func span(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if ConfigStore.shared.c.language == .english {
            return h == 0 ? "\(m) min" : (m == 0 ? "\(h) hr" : "\(h) hr \(m) min")
        }
        return h == 0 ? "\(m) Min." : (m == 0 ? "\(h) Std." : "\(h) Std. \(m) Min.")
    }

    var headline: String {
        switch now.mode {
        case .mainsOnly: Copy.text("Netzbetrieb", "Running on power adapter")
        case .topped: Copy.text("Vollständig geladen", "Fully charged")
        case .resting: Copy.text("Am Netzteil · Ladung pausiert", "On adapter · charging paused")
        case .deficit: Copy.text("Netzteil liefert zu wenig Leistung", "Adapter power is insufficient")
        case .filling: now.minutesToFull.map { Copy.text("Voll in \(Self.span($0))", "Full in \(Self.span($0))") }
            ?? Copy.text("Wird geladen", "Charging")
        case .draining: now.minutesToEmpty.map { Copy.text("Noch \(Self.span($0))", "About \(Self.span($0)) left") }
            ?? Copy.text("Laufzeit wird geschätzt", "Estimating time remaining")
        }
    }

    var compactTime: String? {
        guard let m = now.mode == .filling ? now.minutesToFull : now.minutesToEmpty else { return nil }
        return "\(m / 60):" + String(format: "%02d", m % 60)
    }

    var wearVerdict: String {
        switch now.wear ?? 100 {
        case 92...: Copy.text("Wie neu", "Like new")
        case 84..<92: Copy.text("Guter Zustand", "In good shape")
        case 78..<84: Copy.text("Kapazität gesunken", "Showing wear")
        default: Copy.text("Akkuservice prüfen", "Consider service")
        }
    }
}
