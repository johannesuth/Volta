// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import XCTest
@testable import VoltaLanguageCore

final class AppProfileTests: XCTestCase {
    func testDefaultProfileKeepsTheExistingApplicationSupportFolder() {
        XCTAssertEqual(AppProfile.supportFolderName(arguments: ["Volta"]), "Volta")
    }

    func testNamedProfileGetsItsOwnApplicationSupportFolder() {
        XCTAssertEqual(AppProfile.supportFolderName(arguments: ["Volta", "--profile", "qa-1"]), "Volta-qa-1")
    }

    func testProfileNamesCannotAddPathComponents() {
        XCTAssertEqual(AppProfile.supportFolderName(arguments: ["Volta", "--profile", "../qa/test"]), "Volta-qatest")
    }

    func testMissingOrEmptyProfileFallsBackToTheDefaultFolder() {
        XCTAssertEqual(AppProfile.supportFolderName(arguments: ["Volta", "--profile"]), "Volta")
        XCTAssertEqual(AppProfile.supportFolderName(arguments: ["Volta", "--profile", "///"]), "Volta")
    }
}
