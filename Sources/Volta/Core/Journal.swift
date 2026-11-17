// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import Foundation
import AppKit
import VoltaLanguageCore

/// One point of charge history.
struct Mark: Codable, Identifiable, Equatable {
    var t: TimeInterval      // seconds since 1970
    var p: Int               // level %
    var ac: Bool             // on mains
    var w: Double?           // pack watts
    var c: Double?           // °C
    var id: TimeInterval { t }
    var date: Date { Date(timeIntervalSince1970: t) }
}

/// Append-only JSON-Lines journal (`journal.jsonl`), kept in memory for charts.
/// A point is written when the level or mains state changes, otherwise every 10 minutes.
final class Journal: @unchecked Sendable {
    static let shared = Journal()

    private let io = DispatchQueue(label: "volta.journal")
    private var marks: [Mark] = []
    private let url = ConfigStore.shared.folder.appending(path: "journal.jsonl")
    private var importGate = HistoryImportGate(markerURL: ConfigStore.shared.folder.appending(path: "history-cleared.marker"))
    private var observer: NSObjectProtocol?

    private init() {
        io.sync { loadAndCompact() }
        observer = NotificationCenter.default.addObserver(forName: .powerTick, object: nil, queue: nil) { [weak self] note in
            guard let tick = note.object as? PowerTick else { return }
            self?.consider(tick.now)
        }
        if marks.count < 12 { startSystemLogImport(automatic: true) }
    }

    // MARK: Reading

    func marks(since date: Date) -> [Mark] {
        io.sync { marks.filter { $0.t >= date.timeIntervalSince1970 } }
    }

    /// Average loss in percentage points per hour across on-battery stretches.
    static func lossPerHour(_ list: [Mark]) -> Double? {
        let pairs = zip(list, list.dropFirst()).filter { !$0.0.ac && !$0.1.ac && ($0.1.t - $0.0.t) < 3_600 }
        let hours = pairs.reduce(0.0) { $0 + ($1.1.t - $1.0.t) / 3_600 }
        guard hours >= 0.3 else { return nil }
        let drop = pairs.reduce(0.0) { $0 + Double($1.0.p - $1.1.p) }
        return max(0, drop / hours)
    }

    // MARK: Writing

    private func consider(_ s: PowerSnapshot) {
        guard s.hasPack else { return }
        let submittedAt = io.sync { importGate.powerTickToken }
        io.async { [self] in
            guard importGate.canCommitPowerTick(submittedAt: submittedAt) else { return }
            if let last = marks.last, last.p == s.level, last.ac == s.onMains, s.taken.timeIntervalSince1970 - last.t < 600 { return }
            if let last = marks.last, s.taken.timeIntervalSince1970 - last.t < 20, last.ac == s.onMains { return }
            append(Mark(t: s.taken.timeIntervalSince1970, p: s.level, ac: s.onMains,
                        w: (s.packWatts * 10).rounded() / 10, c: s.celsius.map { ($0 * 10).rounded() / 10 }))
        }
    }

    private func append(_ m: Mark) {
        marks.append(m)
        guard var line = try? JSONEncoder().encode(m) else { return }
        line.append(0x0A)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
        } else {
            try? line.write(to: url)
        }
    }

    private func loadAndCompact() {
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return }
        let horizon = Date.now.timeIntervalSince1970 - Double(ConfigStore.shared.c.keepDays) * 86_400
        let decoder = JSONDecoder()
        marks = raw.split(separator: "\n").compactMap { try? decoder.decode(Mark.self, from: Data($0.utf8)) }
            .filter { $0.t >= horizon }
            .sorted { $0.t < $1.t }
        _ = rewrite()
    }

    @discardableResult
    private func rewrite(_ items: [Mark]? = nil) -> Bool {
        let items = items ?? marks
        let enc = JSONEncoder()
        let body = items.compactMap { try? enc.encode($0) }.map { String(decoding: $0, as: UTF8.self) }.joined(separator: "\n")
        do {
            try (body.isEmpty ? "" : body + "\n").write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func wipe() -> Bool {
        io.sync {
            do {
                try importGate.markHistoryCleared()
            } catch {
                return false
            }
            guard rewrite([]) else { return false }
            marks.removeAll()
            return true
        }
    }

    // MARK: Seed from the system power log

    /// The power-management log records "Using AC/BATT (Charge:NN%)" at every sleep and wake —
    /// enough to draw a meaningful chart on first launch. This method is the explicit user action.
    func importSystemLog() {
        startSystemLogImport(automatic: false)
    }

    private func startSystemLogImport(automatic: Bool) {
        let token: UInt64? = io.sync {
            if automatic { return importGate.automaticImportToken(markCount: marks.count) }
            return importGate.manualImportToken()
        }
        guard let token else { return }

        DispatchQueue.global(qos: .utility).async { [self] in
            let proc = Process()
            proc.executableURL = URL(filePath: "/usr/bin/pmset")
            proc.arguments = ["-g", "log"]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = FileHandle.nullDevice
            guard (try? proc.run()) != nil else { return }
            let text = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            proc.waitUntilExit()

            let pattern = #/^(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d) ([+-])(\d\d)(\d\d).*Using (AC|BATT|Batt)\s*\(Charge:\s*(\d{1,3})%\)/#
            let horizon = Date.now.addingTimeInterval(-Double(ConfigStore.shared.c.keepDays) * 86_400)
            var seeded: [Mark] = []
            for line in text.split(separator: "\n") {
                guard let hit = line.firstMatch(of: pattern), let pct = Int(hit.11) else { continue }
                let offset = (Int(hit.8)! * 3600 + Int(hit.9)! * 60) * (hit.7 == "-" ? -1 : 1)
                var parts = DateComponents(year: Int(hit.1), month: Int(hit.2), day: Int(hit.3),
                                           hour: Int(hit.4), minute: Int(hit.5), second: Int(hit.6))
                parts.timeZone = TimeZone(secondsFromGMT: offset)
                guard let when = Calendar(identifier: .gregorian).date(from: parts), when > horizon else { continue }
                if let last = seeded.last, when.timeIntervalSince1970 - last.t < 120 { continue }
                seeded.append(Mark(t: when.timeIntervalSince1970, p: pct, ac: hit.10 == "AC", w: nil, c: nil))
            }
            guard !seeded.isEmpty else { return }
            io.async { [self] in
                let mayCommit = automatic
                    ? importGate.canCommitAutomaticImport(startedAt: token)
                    : importGate.canCommitManualImport(startedAt: token)
                guard mayCommit else { return }
                let existing = Set(marks.map { Int($0.t) })
                marks = (marks + seeded.filter { !existing.contains(Int($0.t)) }).sorted { $0.t < $1.t }
                _ = rewrite()
            }
        }
    }

    // MARK: Export

    @MainActor func exportCSV() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = Copy.text("Volta-Verlauf.csv", "Volta-History.csv")
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, let target = panel.url else { return }
        let iso = ISO8601DateFormatter()
        let rows = io.sync { marks }.map { m in
            [iso.string(from: m.date), "\(m.p)", m.ac ? Copy.text("Netz", "Adapter") : Copy.text("Akku", "Battery"),
             m.w.map { String(format: "%.1f", $0) } ?? "", m.c.map { String(format: "%.1f", $0) } ?? ""].joined(separator: ";")
        }
        let headings = Copy.text("Zeit;Prozent;Quelle;Akku-Watt;Temperatur", "Time;Percent;Source;Battery watts;Temperature")
        let csv = ([headings] + rows).joined(separator: "\n")
        try? csv.write(to: target, atomically: true, encoding: .utf8)
    }
}
