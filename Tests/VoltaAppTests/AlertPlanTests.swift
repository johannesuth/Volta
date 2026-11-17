import XCTest
@testable import Volta

final class AlertPlanTests: XCTestCase {
    func testDefaultPlanWarnsAtTwentyPercentAndWhenFull() {
        let plan = AlertPlan()
        XCTAssertEqual(plan.triggers.map(\.direction), [.down, .up])
        XCTAssertEqual(plan.triggers.map(\.level), [20, 100])
        XCTAssertTrue(plan.triggers.allSatisfy { $0.presentation == .card })
    }

    func testSwitchedOffAlertsProduceNoRule() {
        var plan = AlertPlan()
        plan.lowOn = false
        XCTAssertEqual(plan.triggers.map(\.direction), [.up])
        plan.fullOn = false
        XCTAssertTrue(plan.triggers.isEmpty)
    }

    func testRulesKeepStableIdentitiesSoTheCooldownHolds() {
        var plan = AlertPlan()
        let before = plan.triggers.map(\.id)
        plan.lowLevel = 15
        plan.style = .both
        XCTAssertEqual(plan.triggers.map(\.id), before)
        XCTAssertTrue(plan.triggers.allSatisfy { $0.presentation == .both })
    }

    func testVeryLowWarningsStayVisibleLonger() {
        var plan = AlertPlan()
        plan.lowLevel = 10
        XCTAssertTrue(plan.triggers.first { $0.direction == .down }!.lingers)
        plan.lowLevel = 20
        XCTAssertFalse(plan.triggers.first { $0.direction == .down }!.lingers)
    }

    func testUntouchedEarlierRuleSetBecomesTheNewDefault() {
        let earlier = [
            Trigger(direction: .down, level: 25, presentation: .aura, tone: "Tink"),
            Trigger(direction: .down, level: 12, presentation: .both, tone: "Funk", lingers: true),
            Trigger(direction: .down, level: 4, presentation: .both, tone: "Basso", lingers: true),
            Trigger(direction: .up, level: 85, presentation: .card, tone: "Ping"),
        ]
        XCTAssertEqual(AlertPlan.migrated(from: earlier), AlertPlan())
    }

    func testCustomEarlierRulesKeepTheirLevels() {
        let custom = [
            Trigger(direction: .down, level: 30, presentation: .banner, tone: "Glass"),
            Trigger(direction: .up, level: 80, presentation: .banner, tone: "Glass", active: false),
        ]
        let plan = AlertPlan.migrated(from: custom)
        XCTAssertEqual(plan.lowLevel, 30)
        XCTAssertTrue(plan.lowOn)
        XCTAssertEqual(plan.fullLevel, 80)
        XCTAssertFalse(plan.fullOn)
        XCTAssertEqual(plan.style, .banner)
        XCTAssertEqual(plan.tone, "Glass")
    }
}
