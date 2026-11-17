// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import AppKit
import Foundation
import IOKit.pwr_mgt

/// The Stay Awake extra. Idle sleep is held off with a power assertion, which needs no permission and
/// ends with the process. Staying awake with the lid closed needs `pmset disablesleep`, which only an
/// administrator may set; see `LidGuard`.
@Observable @MainActor
final class AwakeKeeper {
    static let shared = AwakeKeeper()

    private(set) var active = false
    private(set) var since: Date?
    /// The closed-lid guard is running.
    private(set) var lidHeld = false
    /// Waiting for the administrator password.
    private(set) var lidPending = false
    /// Why the closed-lid mode stopped or could not start, shown under the option.
    private(set) var lidNote: String?

    @ObservationIgnored private var assertion: IOPMAssertionID = 0
    @ObservationIgnored private var assertionType: String?
    @ObservationIgnored private var batteryWatch: Task<Void, Never>?
    @ObservationIgnored private let store = ConfigStore.shared

    private init() {
        // A flag left behind by a crash: its guard has already restored sleep, as Volta's process was gone.
        try? FileManager.default.removeItem(atPath: LidGuard.flagPath)
        observe()
    }

    var installed: Bool { store.c.extras.has(.stayAwake) }

    nonisolated static func assertionType(active: Bool, keepDisplayOn: Bool) -> String? {
        guard active else { return nil }
        // Holding the display awake also holds the system awake.
        return keepDisplayOn ? kIOPMAssertPreventUserIdleDisplaySleep : kIOPMAssertPreventUserIdleSystemSleep
    }

    func set(_ on: Bool) {
        guard on != active, installed || !on else { return }
        active = on
        since = on ? .now : nil
        if on { lidNote = nil }
        apply()
    }

    func toggle() { set(!active) }

    /// The display shortcut: flips "keep the display on" and switches Stay Awake on if needed.
    func toggleDisplay() {
        guard installed else { return }
        store.c.extras.awake.keepDisplayOn.toggle()
        if store.c.extras.awake.keepDisplayOn { set(true) }
    }

    /// Lets the Mac sleep normally again; called on uninstall and when Volta quits.
    func shutdown() {
        set(false)
        stopLid()
    }

    private func observe() {
        let extras = withObservationTracking { store.c.extras } onChange: { [weak self] in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.observe() } }
        }
        if !extras.has(.stayAwake) && active { set(false) } else { apply() }
    }

    private func apply() {
        let prefs = store.c.extras.awake
        let wanted = Self.assertionType(active: active, keepDisplayOn: prefs.keepDisplayOn)
        if wanted != assertionType {
            if assertionType != nil { IOPMAssertionRelease(assertion) }
            assertion = 0
            if let wanted {
                let reason = Copy.text("Volta: Wach bleiben", "Volta: Stay Awake") as CFString
                if IOPMAssertionCreateWithName(wanted as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), reason, &assertion) != kIOReturnSuccess {
                    assertion = 0
                }
            }
            assertionType = wanted
        }
        let wantLid = active && prefs.lidClosed
        if wantLid && !lidHeld && !lidPending { startLid() }
        if !wantLid && (lidHeld || lidPending) { stopLid() }
    }

    // MARK: Closed lid

    private func startLid() {
        guard LidGuard.isShellSafe(LidGuard.flagPath) else {
            refuseLid(Copy.text("Nicht möglich: ungewöhnlicher Ordnername.", "Not possible: unusual folder name."))
            return
        }
        FileManager.default.createFile(atPath: LidGuard.flagPath, contents: nil)
        lidPending = true
        lidNote = nil
        let request = LidGuard.appleScript(
            for: LidGuard.script(pid: ProcessInfo.processInfo.processIdentifier, flag: LidGuard.flagPath),
            prompt: Copy.text("Volta möchte deinen Mac auch zugeklappt wach halten.",
                              "Volta wants to keep your Mac awake with the lid closed."))
        let task = Process()
        task.executableURL = URL(filePath: "/usr/bin/osascript")
        task.arguments = ["-e", request]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        task.terminationHandler = { process in
            let approved = process.terminationStatus == 0
            DispatchQueue.main.async { MainActor.assumeIsolated { AwakeKeeper.shared.lidStarted(approved) } }
        }
        do { try task.run() } catch { lidStarted(false) }
    }

    private func lidStarted(_ approved: Bool) {
        guard lidPending else { return }
        lidPending = false
        guard approved else {
            refuseLid(Copy.text("Nicht erlaubt. Zum Aktivieren ist dein Administratorpasswort nötig.",
                                "Not allowed. Your administrator password is needed to turn this on."))
            return
        }
        // The user may have switched off while the password dialog was open.
        guard active && store.c.extras.awake.lidClosed else { stopLid(); return }
        lidHeld = true
        watchBattery()
    }

    private func refuseLid(_ note: String) {
        try? FileManager.default.removeItem(atPath: LidGuard.flagPath)
        lidPending = false
        lidHeld = false
        lidNote = note
        store.c.extras.awake.lidClosed = false
    }

    private func stopLid() {
        // Removing the flag ends the guard within two seconds, which turns normal sleep back on.
        try? FileManager.default.removeItem(atPath: LidGuard.flagPath)
        lidHeld = false
        lidPending = false
        batteryWatch?.cancel()
        batteryWatch = nil
    }

    /// A closed MacBook that never sleeps would empty its battery in a bag; stop at 10 % on battery.
    private func watchBattery() {
        batteryWatch?.cancel()
        batteryWatch = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard let self, self.lidHeld else { return }
                let now = Telemetry.shared.now
                if now.hasPack && LidGuard.shouldRelease(level: now.level, onMains: now.onMains) {
                    self.refuseLid(Copy.text("Beendet, weil der Akku unter 10 % liegt.", "Stopped because the battery is below 10%."))
                    self.stopLid()
                    return
                }
            }
        }
    }
}

/// Keeps a closed MacBook awake with `pmset -a disablesleep 1` and guarantees it is undone.
/// After one administrator approval a tiny root shell loop holds the setting only while Volta's
/// process is alive and a flag file exists, then runs `pmset -a disablesleep 0`. So switching off,
/// quitting and even a crash all restore normal sleep without asking for the password again.
enum LidGuard {
    static let flagPath = FileManager.default.temporaryDirectory
        .appending(path: "com.johannesuth.volta.lid").path(percentEncoded: false)

    static func shouldRelease(level: Int, onMains: Bool) -> Bool {
        !onMains && level <= 10
    }

    /// The path is placed into a root shell command, so only plain path characters are allowed.
    static func isShellSafe(_ path: String) -> Bool {
        !path.isEmpty && path.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "/._-".contains($0)) }
    }

    static func script(pid: Int32, flag: String, pmset: String = "/usr/bin/pmset") -> String {
        "F=\(flag); P=\(pid); \(pmset) -a disablesleep 1; "
            + "while /bin/kill -0 $P 2>/dev/null && [ -e $F ]; do /bin/sleep 2; done; "
            + "\(pmset) -a disablesleep 0"
    }

    /// The guard runs in the background, so the request returns as soon as it is approved.
    static func appleScript(for script: String, prompt: String) -> String {
        let safePrompt = prompt.replacingOccurrences(of: "\\", with: "").replacingOccurrences(of: "\"", with: "")
        return "do shell script \"/bin/sh -c '\(script)' >/dev/null 2>&1 &\" with prompt \"\(safePrompt)\" with administrator privileges"
    }
}
