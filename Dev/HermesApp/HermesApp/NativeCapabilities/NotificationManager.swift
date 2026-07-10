import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// - Parameter sessionId: when present, tags the notification with its
    ///   Hermes chat session so the "Open Chat" / default tap action
    ///   (see NotificationCategories.handle) can deep-link straight to it.
    func schedule(title: String, body: String, delay: TimeInterval, sessionId: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = NotificationCategories.agentUpdate
        if let sessionId { content.userInfo = ["sessionId": sessionId] }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delay, 1), repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
}
