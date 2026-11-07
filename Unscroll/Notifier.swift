import Foundation
import UserNotifications

enum Notifier {
    private static let focusID = "focus-end"

    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    static func scheduleFocusEnd(at date: Date, minutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Focus done"
        content.body = "\(minutes) minutes without the scroll. Open Unscroll to see how you did."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: focusID, content: content, trigger: trigger))
    }

    static func cancelFocusEnd() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [focusID])
    }
}
