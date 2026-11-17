import XCTest
@testable import Volta

final class TileExpansionTests: XCTestCase {
    func testSeveralSectionsCanStayOpenTogether() {
        var expansion = TileExpansion()
        XCTAssertFalse(expansion.contains(.trend))

        expansion.toggle(.trend)
        expansion.toggle(.balance)
        XCTAssertTrue(expansion.contains(.trend))
        XCTAssertTrue(expansion.contains(.balance))

        expansion.toggle(.trend)
        XCTAssertFalse(expansion.contains(.trend))
        XCTAssertTrue(expansion.contains(.balance))
    }

    func testCollapsingForSpaceClosesTheEarliestOpenedSection() {
        var expansion = TileExpansion(openTiles: [.vitals, .trend, .balance])

        XCTAssertTrue(expansion.collapseOldest())
        XCTAssertEqual(expansion.openTiles, [.trend, .balance])

        var empty = TileExpansion()
        XCTAssertFalse(empty.collapseOldest())
    }

    func testHealthAndAppEnergyAreOpenByDefaultAndHistoryStaysCollapsed() {
        XCTAssertEqual(Config().expansion.openTiles, [.vitals, .apps])
        XCTAssertFalse(Config().expansion.contains(.trend))
    }
}
