import Foundation

/// Handoff support: lets a user start a Hermes conversation on iPhone and
/// continue it on Mac (or vice versa) via NSUserActivity continuation.
/// Also marks activities as Spotlight-eligible so recent chats appear in
/// system search without needing full CSSearchableIndex round trips.
enum HandoffManager {
    static let chatActivityType = "au.aiadvantage.HermesApp.chat"

    static func makeChatActivity(sessionId: String, title: String) -> NSUserActivity {
        let activity = NSUserActivity(activityType: chatActivityType)
        activity.title = title
        activity.userInfo = ["sessionId": sessionId]
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true // helps Siri Suggestions surface it proactively
        activity.persistentIdentifier = "chat-\(sessionId)"
        activity.webpageURL = ServerConfig.shared.baseURL?.appendingPathComponent("/chat/\(sessionId)")
        return activity
    }

    /// Called from scene(_:continue:) on both iOS and macOS.
    static func resolve(_ userActivity: NSUserActivity) -> URL? {
        guard userActivity.activityType == chatActivityType,
              let sessionId = userActivity.userInfo?["sessionId"] as? String,
              let base = ServerConfig.shared.baseURL else {
            return userActivity.webpageURL
        }
        return base.appendingPathComponent("/chat/\(sessionId)")
    }
}
