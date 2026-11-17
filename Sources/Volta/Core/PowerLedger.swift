import AppKit
import Darwin
import Observation

struct Consumer: Identifiable, Equatable {
    let id: String
    let title: String
    let watts: Double
    let fraction: Double
    let bundleURL: URL?

    static func == (l: Consumer, r: Consumer) -> Bool { l.id == r.id && l.watts == r.watts }
}

/// Turns an app's share of the measured app energy into a plain percentage ("31 %").
/// Milliwatts mean little to most people; a share answers "which app uses most of my battery?".
enum EnergyShare {
    static func label(_ fraction: Double) -> String {
        guard fraction.isFinite else { return "< 1 %" }
        let percent = Int((min(max(fraction, 0), 1) * 100).rounded())
        return percent < 1 ? "< 1 %" : "\(percent) %"
    }
}

/// Measures how much power each app draws, from the kernel's per-process energy counters.
/// Processes are enumerated with `sysctl(KERN_PROC_ALL)`; helpers count toward their host `.app`.
@Observable @MainActor
final class PowerLedger {
    static let shared = PowerLedger()

    private(set) var ranking: [Consumer] = []
    private(set) var total = 0.0

    @ObservationIgnored private var lastCounters: [Int32: UInt64] = [:]
    @ObservationIgnored private var lastAt: ContinuousClock.Instant?
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var holders = 0
    @ObservationIgnored private var icons: [String: NSImage] = [:]

    private init() {}

    func watch() -> Telemetry.Lease {
        holders += 1
        if loop == nil {
            loop = Task { [weak self] in
                while !Task.isCancelled {
                    await self?.tick()
                    try? await Task.sleep(for: .seconds(2.5))
                }
            }
        }
        return Telemetry.Lease { [weak self] in
            DispatchQueue.main.async { MainActor.assumeIsolated {
                guard let self else { return }
                self.holders -= 1
                if self.holders <= 0 { self.loop?.cancel(); self.loop = nil; self.lastAt = nil }
            } }
        }
    }

    private nonisolated static func pids() -> [Int32] {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var bytes = 0
        guard sysctl(&mib, 4, nil, &bytes, nil, 0) == 0, bytes > 0 else { return [] }
        let stride = MemoryLayout<kinfo_proc>.stride
        var table = [kinfo_proc](repeating: kinfo_proc(), count: bytes / stride + 16)
        bytes = table.count * stride
        guard sysctl(&mib, 4, &table, &bytes, nil, 0) == 0 else { return [] }
        return table.prefix(bytes / stride).map { $0.kp_proc.p_pid }.filter { $0 > 0 }
    }

    private nonisolated static func counters() -> [Int32: (energy: UInt64, path: String)] {
        var out: [Int32: (UInt64, String)] = [:]
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        for pid in pids() {
            var usage = rusage_info_v6()
            // The API takes the struct's own address typed as `rusage_info_t *`.
            let rc = withUnsafeMutableBytes(of: &usage) { raw in
                proc_pid_rusage(pid, RUSAGE_INFO_V6, raw.baseAddress!.assumingMemoryBound(to: rusage_info_t?.self))
            }
            guard rc == 0 else { continue }
            let len = proc_pidpath(pid, &buffer, UInt32(buffer.count))
            out[pid] = (usage.ri_energy_nj, len > 0 ? String(cString: buffer) : "")
        }
        return out
    }

    private func tick() async {
        let snapshot = await Task.detached(priority: .utility) { Self.counters() }.value
        let instant = ContinuousClock.now
        defer {
            lastCounters = snapshot.mapValues(\.energy)
            lastAt = instant
        }
        guard let previousAt = lastAt else { return }
        let seconds = (instant - previousAt) / .seconds(1)
        guard seconds > 0.3 else { return }

        var buckets: [String: (watts: Double, title: String, url: URL?)] = [:]
        for (pid, entry) in snapshot {
            guard let old = lastCounters[pid], entry.energy > old else { continue }
            let watts = Double(entry.energy - old) / 1_000_000_000 / seconds
            let (key, title, url) = Self.owner(of: entry.path, pid: pid)
            buckets[key, default: (0, title, url)].watts += watts
        }
        let sum = buckets.values.reduce(0) { $0 + $1.watts }
        total = sum
        ranking = buckets
            .sorted { $0.value.watts > $1.value.watts }
            .prefix(12)
            .map { Consumer(id: $0.key, title: $0.value.title, watts: $0.value.watts,
                            fraction: sum > 0 ? $0.value.watts / sum : 0, bundleURL: $0.value.url) }
    }

    private nonisolated static func owner(of path: String, pid: Int32) -> (String, String, URL?) {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        if let idx = parts.firstIndex(where: { $0.hasSuffix(".app") }) {
            let appPath = parts[...idx].joined(separator: "/")
            let title = String(parts[idx].dropLast(4))
            return (appPath, title, URL(filePath: appPath))
        }
        let name = parts.last.map(String.init) ?? ""
        return (path.isEmpty ? "pid:\(pid)" : path, name.isEmpty ? "PID \(pid)" : name, nil)
    }

    func icon(for c: Consumer) -> NSImage {
        if let hit = icons[c.id] { return hit }
        let img = c.bundleURL.map { NSWorkspace.shared.icon(forFile: $0.path) } ?? NSImage(systemSymbolName: "gearshape.2.fill", accessibilityDescription: nil)!
        icons[c.id] = img
        return img
    }

    /// Asks the app (and only GUI apps) to quit.
    func requestQuit(_ c: Consumer) {
        guard let url = c.bundleURL else { return }
        NSWorkspace.shared.runningApplications.filter { $0.bundleURL == url }.forEach { $0.terminate() }
    }
}
