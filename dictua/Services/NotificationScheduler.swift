import Foundation
import UserNotifications

public final class NotificationScheduler {
    public static let shared = NotificationScheduler()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    /// Request notification permission.
    public func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    /// Set app icon badge count.
    public func setBadge(count: Int) {
        Task { @MainActor in
            UNUserNotificationCenter.current().setBadgeCount(count) { _ in }
        }
    }

    /// Clear badge. Call when app opens.
    public func clearBadge() {
        setBadge(count: 0)
    }
}
