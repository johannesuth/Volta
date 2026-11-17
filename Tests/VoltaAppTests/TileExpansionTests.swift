import XCTest
@testable import Volta

final class TileExpansionTests: XCTestCase {
    func testOpeningAnotherSectionCollapsesThePreviousOne() {
        var expansion = TileExpansion()
        XCTAssertFalse(expansion.contains(.trend))

        expansion.toggle(.trend)
        XCTAssertTrue(expansion.contains(.trend))

        expansion.toggle(.vitals)
        XCTAssertFalse(expansion.contains(.trend))
        XCTAssertTrue(expansion.contains(.vitals))

        expansion.toggle(.vitals)
        XCTAssertFalse(expansion.contains(.vitals))
    }

    func testDashboardOpensWithTheSmallPowerFlowSectionExpanded() {
        XCTAssertTrue(TileExpansion.opening(shown: [.charge, .balance, .trend]).contains(.balance))
        XCTAssertNil(TileExpansion.opening(shown: [.charge, .trend]).expandedTile)
    }
}
