// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import AppKit
import UserNotifications

/// Lets macOS show Volta's notifications even while one of Volta's own windows is in front
/// (by default macOS hides them for the active app), and opens the dashboard when one is clicked.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationPresenter()
    static let foregroundOptions: UNNotificationPresentationOptions = [.banner, .list]

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        Self.foregroundOptions
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if let url = URL(string: "volta://open") {
            await MainActor.run { _ = NSWorkspace.shared.open(url) }
        }
    }
}
