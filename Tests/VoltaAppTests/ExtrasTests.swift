// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import AppKit
import IOKit.pwr_mgt
import SwiftUI
import XCTest
import VoltaLanguageCore
@testable import Volta

/// Settings → Extras: optional tools that ship with Volta, stay off until installed, and can be removed again.
final class ExtrasTests: XCTestCase {
    // MARK: Catalog and settings

    func testStayAwakeIsTheFirstExtraAndNothingIsInstalledByDefault() {
        XCTAssertEqual(ExtraID.allCases, [.stayAwake])
        XCTAssertTrue(Config().extras.installed.isEmpty)
        XCTAssertEqual(ExtraID.stayAwake.title(language: .german), "Wach bleiben")
        XCTAssertEqual(ExtraID.stayAwake.title(language: .english), "Stay Awake")
    }

    func testEachExtraIsDescribedInTwoSentences() {
        for extra in ExtraID.allCases {
            for language in AppLanguage.allCases {
                let text = extra.summary(language: language)
                let sentences = text.split(whereSeparator: { ".!?".contains($0) })
                    .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                XCTAssertEqual(sentences.count, 2, "\(extra) \(language): \(text)")
            }
        }
    }

    func testInstallingTwiceKeepsOneEntryAndUninstallingRemovesIt() {
        var extras = ExtrasConfig()
        extras.install(.stayAwake)
        extras.install(.stayAwake)
        XCTAssertEqual(extras.installed, [.stayAwake])
        XCTAssertTrue(extras.has(.stayAwake))
        extras.uninstall(.stayAwake)
        XCTAssertFalse(extras.has(.stayAwake))
    }

    func testSettingsFromOlderVersionsLoadWithoutExtras() {
        let loaded = Config.merged(defaults: Config(), stored: ["glyph": "cell", "language": "de"])
        XCTAssertEqual(loaded?.extras, ExtrasConfig())
        let partial = Config.merged(defaults: Config(), stored: ["extras": ["installed": ["stayAwake"]]])
        XCTAssertEqual(partial?.extras.installed, [.stayAwake])
        XCTAssertEqual(partial?.extras.awake, AwakePrefs(), "options added later get their defaults")
    }

    func testStayAwakeShortcutsDifferFromTheDashboardShortcut() {
        let prefs = AwakePrefs()
        XCTAssertEqual(prefs.shortcut.label, "⌃⌥W")
        XCTAssertEqual(prefs.displayShortcut.label, "⌃⌥D")
        XCTAssertEqual(Set([prefs.shortcut, prefs.displayShortcut, KeyCombo.standard]).count, 3)
        XCTAssertTrue(prefs.shortcutOn)
        XCTAssertTrue(prefs.displayShortcutOn)
        XCTAssertFalse(prefs.keepDisplayOn)
        XCTAssertFalse(prefs.lidClosed)
    }

    func testShortcutClashIsDetected() {
        XCTAssertTrue(ShortcutClash.exists(KeyCombo.standard, among: [KeyCombo.standard, AwakePrefs().shortcut]))
        XCTAssertFalse(ShortcutClash.exists(AwakePrefs().displayShortcut, among: [KeyCombo.standard, AwakePrefs().shortcut]))
    }

    // MARK: Keeping the Mac awake

    func testAssertionFollowsTheSwitchAndTheDisplayOption() {
        XCTAssertNil(AwakeKeeper.assertionType(active: false, keepDisplayOn: true))
        XCTAssertEqual(AwakeKeeper.assertionType(active: true, keepDisplayOn: false), kIOPMAssertPreventUserIdleSystemSleep)
        XCTAssertEqual(AwakeKeeper.assertionType(active: true, keepDisplayOn: true), kIOPMAssertPreventUserIdleDisplaySleep)
    }

    func testClosedLidModeEndsOnLowBatteryOnlyWhenUnplugged() {
        XCTAssertTrue(LidGuard.shouldRelease(level: 10, onMains: false))
        XCTAssertFalse(LidGuard.shouldRelease(level: 11, onMains: false))
        XCTAssertFalse(LidGuard.shouldRelease(level: 4, onMains: true))
    }

    func testOnlyShellSafeFlagPathsAreAccepted() {
        XCTAssertTrue(LidGuard.isShellSafe("/var/folders/ab/xy_z-1/T/com.johannesuth.volta.lid"))
        XCTAssertFalse(LidGuard.isShellSafe("/Users/a b/flag"))
        XCTAssertFalse(LidGuard.isShellSafe("/tmp/x';rm -rf ~;'"))
        XCTAssertTrue(LidGuard.isShellSafe(LidGuard.flagPath))
    }

    func testAdministratorRequestRunsTheGuardInTheBackground() {
        let script = LidGuard.script(pid: 4242, flag: "/tmp/flag")
        let request = LidGuard.appleScript(for: script, prompt: "Volta")
        XCTAssertTrue(request.hasPrefix("do shell script \"/bin/sh -c '"))
        XCTAssertTrue(request.contains("' >/dev/null 2>&1 &\""), "returns at once; the guard keeps running")
        XCTAssertTrue(request.hasSuffix("with administrator privileges"))
        XCTAssertFalse(script.contains("'") || script.contains("\""), "no quotes that could break out")
    }

    // The guard runs for real here, with a stand-in for pmset that only logs its arguments.
    private func runGuard(stop: (_ flag: URL, _ holder: Process) throws -> Void) throws -> [String] {
        let dir = FileManager.default.temporaryDirectory.appending(path: "lidguard-\(UUID().uuidString.prefix(8))")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let log = dir.appending(path: "pmset.log")
        let fake = dir.appending(path: "pmset")
        try "#!/bin/sh\necho \"$*\" >> \(log.path)\n".write(to: fake, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fake.path)
        let flag = dir.appending(path: "flag")
        FileManager.default.createFile(atPath: flag.path, contents: nil)

        let holder = Process()
        holder.executableURL = URL(filePath: "/bin/sleep")
        holder.arguments = ["30"]
        try holder.run()

        let guardProcess = Process()
        guardProcess.executableURL = URL(filePath: "/bin/sh")
        guardProcess.arguments = ["-c", LidGuard.script(pid: holder.processIdentifier, flag: flag.path, pmset: fake.path)]
        try guardProcess.run()
        Thread.sleep(forTimeInterval: 0.8)
        let during = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
        XCTAssertEqual(during, "-a disablesleep 1\n", "sleep is disabled while Volta runs")

        try stop(flag, holder)
        let deadline = Date.now.addingTimeInterval(6)
        while guardProcess.isRunning && Date.now < deadline { Thread.sleep(forTimeInterval: 0.1) }
        if holder.isRunning { holder.terminate() }
        XCTAssertFalse(guardProcess.isRunning, "the guard ends by itself")
        return ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
    }

    func testLidGuardRestoresSleepWhenTurnedOff() throws {
        let calls = try runGuard { flag, _ in try FileManager.default.removeItem(at: flag) }
        XCTAssertEqual(calls, ["-a disablesleep 1", "-a disablesleep 0"])
    }

    func testLidGuardRestoresSleepWhenVoltaQuitsOrCrashes() throws {
        let calls = try runGuard { _, holder in holder.terminate() }
        XCTAssertEqual(calls, ["-a disablesleep 1", "-a disablesleep 0"])
    }

    // MARK: Type

    func testTextIsFivePercentSmallerAndSlightlyThinner() {
        XCTAssertEqual(Dim().pointSize(10), 11.07, accuracy: 0.001, "1.165 × 0.95")
        XCTAssertEqual(Dim.weightValue(.regular), 480)
        XCTAssertEqual(Dim.weightValue(.medium), 480)
        XCTAssertEqual(Dim.weightValue(.semibold), 555)
        XCTAssertEqual(Dim.weightValue(.bold), 660)
        for rounded in [false, true] {
            let font = Dim.font(size: 12, weight: .semibold, rounded: rounded)
            let axes = CTFontCopyVariation(font) as? [NSNumber: NSNumber]
            XCTAssertEqual(axes?[NSNumber(value: 0x7767_6874)]?.doubleValue ?? 0, 555, accuracy: 1, "rounded: \(rounded)")
        }
    }

    // MARK: Wording

    func testShortcutConfirmationExplainsWhatHappens() {
        var prefs = AwakePrefs()
        XCTAssertEqual(AwakeStatus.toastDetail(active: false, prefs: prefs, language: .german), "Dein Mac schläft wieder wie gewohnt.")
        XCTAssertEqual(AwakeStatus.toastDetail(active: true, prefs: prefs, language: .german), "Dein Mac schläft nicht ein.")
        prefs.keepDisplayOn = true
        prefs.lidClosed = true
        XCTAssertEqual(AwakeStatus.toastDetail(active: true, prefs: prefs, language: .german), "Bildschirm bleibt an, auch zugeklappt.")
        XCTAssertEqual(AwakeStatus.toastDetail(active: true, prefs: prefs, language: .english), "Display stays on, also with the lid closed.")
    }

    func testStatusSaysSinceWhen() {
        var parts = DateComponents()
        parts.year = 2026; parts.month = 11; parts.day = 17; parts.hour = 14; parts.minute = 2
        let date = Calendar.current.date(from: parts)!
        XCTAssertEqual(AwakeStatus.since(date, language: .german), "An seit 14:02 Uhr")
        XCTAssertEqual(AwakeStatus.since(date, language: .english), "On since 2:02 PM")
    }

}
