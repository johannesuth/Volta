import AppKit
import XCTest
@testable import Volta

@MainActor
final class DropWindowTests: XCTestCase {
    func testPinnedPanelIsNotHiddenWhenAnotherAppBecomesActive() {
        let window = DropWindow.make()
        XCTAssertFalse(window.hidesOnDeactivate)
        XCTAssertTrue(window.canBecomeKey)
    }
}

final class LookTests: XCTestCase {
    func testAppearanceChoicesStartWithAutomatic() {
        XCTAssertEqual(Look.allCases, [.auto, .day, .night])
        XCTAssertEqual(Config().look, .auto)
    }

    @MainActor
    func testEachChoiceMapsToTheMatchingAppKitAppearance() {
        XCTAssertNil(Look.auto.appearance)
        XCTAssertEqual(Look.day.appearance?.name, .aqua)
        XCTAssertEqual(Look.night.appearance?.name, .darkAqua)
    }
}

final class LoginItemTests: XCTestCase {
    func testLegacyLaunchAgentIsRemovedAndReported() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let plist = folder.appending(path: "com.johannesuth.volta.autostart.plist")
        try Data("<plist/>".utf8).write(to: plist)

        XCTAssertTrue(LoginItem.removeLegacyAgent(in: folder))
        XCTAssertFalse(FileManager.default.fileExists(atPath: plist.path(percentEncoded: false)))
        XCTAssertFalse(LoginItem.removeLegacyAgent(in: folder), "nothing left to remove")
    }
}

final class ClockTextTests: XCTestCase {
    func testRemainingMinutesBecomeAClockTimeInTheAppLanguage() {
        var parts = DateComponents()
        parts.year = 2026; parts.month = 11; parts.day = 17; parts.hour = 14; parts.minute = 5
        let start = Calendar.current.date(from: parts)!

        XCTAssertEqual(ClockText.until(minutes: 95, from: start, language: .german), "15:40 Uhr")
        XCTAssertEqual(ClockText.until(minutes: 95, from: start, language: .english), "3:40 PM")
    }
}
