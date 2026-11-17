// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import UserNotifications
import XCTest
@testable import Volta

final class AlertOptionsTests: XCTestCase {
    func testStoredSettingsMergeIntoDefaultsAtEveryLevel() throws {
        // An alerts block written by 2.2 lacks the new keys; it must keep its values and gain the defaults.
        let stored: [String: Any] = ["alerts": ["lowLevel": 15, "style": "banner"], "language": "en"]
        let merged = Config.merged(defaults: Config(), stored: stored)
        let cfg = try XCTUnwrap(merged)

        XCTAssertEqual(cfg.alerts.lowLevel, 15)
        XCTAssertEqual(cfg.alerts.style, .banner)
        XCTAssertEqual(cfg.alerts.color, .level)
        XCTAssertEqual(cfg.language, .english)
    }

    func testNewAlertDefaults() {
        let plan = AlertPlan()
        XCTAssertEqual(plan.color, .level)
        XCTAssertEqual(AlertColor.allCases.first, .level)
    }

    @MainActor
    func testEveryAlertShowsBrieflyForFiveSeconds() {
        // The display time is fixed and not a setting.
        XCTAssertEqual(AlertPlan.showSeconds, 5)
        let snapshot = PowerSnapshot()
        let plan = AlertPlan()
        for (direction, level) in [(Trigger.Direction.down, 30), (.down, 5), (.up, 100)] {
            let trigger = Trigger(direction: direction, level: level, presentation: .card, tone: "Glass")
            XCTAssertEqual(Sentinel.notice(for: trigger, level: level, snapshot: snapshot, plan: plan).seconds, 5)
        }
    }

    func testAnOldDurationKeyIsIgnored() throws {
        let data = Data(#"{"lowLevel": 25, "duration": "untilClicked"}"#.utf8)
        let plan = try JSONDecoder().decode(AlertPlan.self, from: data)
        XCTAssertEqual(plan.lowLevel, 25)
    }

    func testFixedColorsOverrideTheLevelColors() {
        XCTAssertEqual(AlertColor.level.swatch(direction: .down, level: 8), .alarm)
        XCTAssertEqual(AlertColor.level.swatch(direction: .down, level: 18), .warn)
        XCTAssertEqual(AlertColor.level.swatch(direction: .down, level: 40), .accent)
        XCTAssertEqual(AlertColor.level.swatch(direction: .up, level: 100), .good)
        XCTAssertEqual(AlertColor.rose.swatch(direction: .down, level: 8), .rose)
    }

    func testNotificationsAreShownEvenWhileVoltaIsInFront() {
        XCTAssertEqual(NotificationPresenter.foregroundOptions, [.banner, .list])
    }
}
