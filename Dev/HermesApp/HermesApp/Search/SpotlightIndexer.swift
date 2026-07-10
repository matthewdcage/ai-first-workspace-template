import CoreSpotlight
import Foundation

/// Indexes Hermes chat sessions and skills into classic iOS/macOS Spotlight
/// (CSSearchableIndex) so they surface in system-wide search — independent
/// of, and complementary to, the App Intents semantic index that
/// `IndexedEntity` conformance in HermesEntities.swift feeds automatically.
enum SpotlightIndexer {

    static func reindexAll() {
        Task {
            let sessions = await HermesSessionStore.shared.recentSessions()
            let skills = await HermesSessionStore.shared.availableSkills()
            index(sessions: sessions)
            index(skills: skills)
        }
    }

    static func index(sessions: [ChatSessionEntity]) {
        let items = sessions.map { session -> CSSearchableItem in
            let attrs = CSSearchableItemAttributeSet(contentType: .text)
            attrs.title = session.title
            attrs.contentDescription = session.lastMessagePreview
            attrs.contentModificationDate = session.updatedAt
            attrs.keywords = ["Hermes", "chat", "agent"]

            let item = CSSearchableItem(
                uniqueIdentifier: "chat-\(session.id)",
                domainIdentifier: "au.aiadvantage.HermesApp.sessions",
                attributeSet: attrs
            )
            item.expirationDate = Date().addingTimeInterval(60 * 60 * 24 * 30) // 30 days
            return item
        }
        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error { print("[Spotlight] session index error: \(error)") }
        }
    }

    static func index(skills: [HermesSkillEntity]) {
        let items = skills.map { skill -> CSSearchableItem in
            let attrs = CSSearchableItemAttributeSet(contentType: .text)
            attrs.title = skill.name
            attrs.contentDescription = skill.summary
            attrs.keywords = ["Hermes", "skill", "capability"]

            return CSSearchableItem(
                uniqueIdentifier: "skill-\(skill.id)",
                domainIdentifier: "au.aiadvantage.HermesApp.skills",
                attributeSet: attrs
            )
        }
        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error { print("[Spotlight] skill index error: \(error)") }
        }
    }

    /// Resolves a Spotlight tap (NSUserActivity with CSSearchableItemActionType)
    /// back to a deep link the WebView can load.
    static func deepLink(for userActivity: NSUserActivity) -> URL? {
        guard userActivity.activityType == CSSearchableItemActionType,
              let uniqueId = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
              let base = ServerConfig.shared.baseURL else { return nil }

        if uniqueId.hasPrefix("chat-") {
            let sessionId = String(uniqueId.dropFirst("chat-".count))
            return base.appendingPathComponent("/chat/\(sessionId)")
        } else if uniqueId.hasPrefix("skill-") {
            let skillId = String(uniqueId.dropFirst("skill-".count))
            return base.appendingPathComponent("/skills/\(skillId)")
        }
        return nil
    }

    static func clearAll() {
        CSSearchableIndex.default().deleteAllSearchableItems()
    }
}
