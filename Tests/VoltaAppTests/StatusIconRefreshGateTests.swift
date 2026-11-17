import XCTest
@testable import Volta

final class StatusIconRefreshGateTests: XCTestCase {
    func testRepeatedInvalidationsAreDeferredUntilTheMinimumInterval() {
        var gate = StatusIconRefreshGate(minimumInterval: 0.25)
        let first = Date(timeIntervalSinceReferenceDate: 100)

        XCTAssertEqual(gate.delayUntilAllowed(at: first), 0, accuracy: 0.0001)
        gate.recordRefresh(at: first)

        XCTAssertEqual(gate.delayUntilAllowed(at: first.addingTimeInterval(0.10)), 0.15, accuracy: 0.0001)
        XCTAssertEqual(gate.delayUntilAllowed(at: first.addingTimeInterval(0.25)), 0, accuracy: 0.0001)
    }
}
