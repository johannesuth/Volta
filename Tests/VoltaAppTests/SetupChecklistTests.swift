import ServiceManagement
import UserNotifications
import XCTest
@testable import Volta

final class SetupChecklistTests: XCTestCase {
    func testNotificationStatusMapsToGrant() {
        XCTAssertEqual(Grant(notifications: .notDetermined), .unknown)
        XCTAssertEqual(Grant(notifications: .denied), .denied)
        XCTAssertEqual(Grant(notifications: .authorized), .granted)
        XCTAssertEqual(Grant(notifications: .provisional), .granted)
    }

    func testLoginItemStatusMapsToGrant() {
        XCTAssertEqual(Grant(login: .notRegistered), .unknown)
        XCTAssertEqual(Grant(login: .enabled), .granted)
        XCTAssertEqual(Grant(login: .requiresApproval), .pending)
        XCTAssertEqual(Grant(login: .notFound), .denied)
    }

    func testPrimaryButtonAsksUntilNothingIsUndecided() {
        XCTAssertTrue(SetupChecklist(notifications: .unknown, login: .unknown).needsRequest)
        XCTAssertTrue(SetupChecklist(notifications: .granted, login: .unknown).needsRequest)
        XCTAssertTrue(SetupChecklist(notifications: .unknown, login: .granted).needsRequest)
        XCTAssertFalse(SetupChecklist(notifications: .denied, login: .pending).needsRequest)
        XCTAssertFalse(SetupChecklist(notifications: .granted, login: .granted).needsRequest)
        XCTAssertTrue(SetupChecklist(notifications: .granted, login: .granted).allGranted)
        XCTAssertFalse(SetupChecklist(notifications: .granted, login: .pending).allGranted)
    }
}
