import XCTest
@testable import Volta

final class URLQueryParametersTests: XCTestCase {
    func testDuplicateQueryParameterIsRejectedInsteadOfCrashing() throws {
        let url = try XCTUnwrap(URL(string: "volta://zoom?to=1&to=2"))

        XCTAssertNil(URLQueryParameters.parse(url))
    }

    func testUniqueQueryParametersArePreserved() throws {
        let url = try XCTUnwrap(URL(string: "volta://demo?level=8&up"))

        XCTAssertEqual(URLQueryParameters.parse(url), ["level": "8", "up": ""])
    }
}
