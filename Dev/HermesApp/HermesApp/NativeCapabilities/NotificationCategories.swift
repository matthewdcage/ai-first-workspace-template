import UserNotifications

/// Rich, actionable notification categories — lets a user reply to a
/// Hermes update or jump straight to a chat session from the lock screen
/// / Notification Center without opening the app first.
enum NotificationCategories {
    static let agentUpdate = "HERMES_AGENT_UPDATE"

    static let replyAction = "HERMES_REPLY"
    static let openAction = "HERMES_OPEN"
    static let dismissAction = "HERMES_DISMISS"

    static func registerAll() {
        let reply = UNTextInputNotificationAction(
            identifier: replyAction,
            title: "Reply",
            options: [],
            textInputButtonTitle: "Send",
            textInputPlaceholder: "Message Hermes…"
        )
        let open = UNNotificationAction(
            identifier: openAction,
            title: "Open Chat",
            options: [.foreground]
        )
        let dismiss = UNNotificationAction(
            identifier: dismissAction,
            title: "Dismiss",
            options: [.destructive]
        )

        let category = UNNotificationCategory(
            identifier: agentUpdate,
            actions: [reply, open, dismiss],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// Handles the action tapped by the user; call from
    /// `userNotificationCenter(_:didReceive:withCompletionHandler:)`.
    static func handle(response: UNNotificationResponse, sessionId: String?, webView: WKWebView?) {
        switch response.actionIdentifier {
        case replyAction:
            if let textResponse = response as? UNTextInputNotificationResponse {
                Task {
                    _ = try? await HermesAPIClient.shared.chat(message: textResponse.userText)
                }
            }
        case openAction, UNNotificationDefaultActionIdentifier:
            guard let sessionId, let base = ServerConfig.shared.baseURL else { return }
            let url = base.appendingPathComponent("/chat/\(sessionId)")
            webView?.load(URLRequest(url: url))
        default:
            break
        }
    }
}

import WebKit
