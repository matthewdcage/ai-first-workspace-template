import AppIntents
import Foundation

/// AppEntity definitions that make Hermes content discoverable to Siri,
/// Spotlight's semantic index, and Shortcuts.
///
/// Assistant Schema note (WWDC26, iOS/macOS 27): Apple's `@AppEntity(schema:)`
/// / `@AssistantIntent(schema:)` macros bind an entity or intent to a
/// system-defined domain — messages, mail, photos, documents — so Siri
/// gets structured vocabulary "for free." None of the announced domains is
/// a semantic match for "AI agent chat session" or "agent skill": the
/// `.messages` domain in particular implies sender/recipient semantics a
/// Hermes session doesn't have, and force-fitting it would make Siri infer
/// things about the entity that aren't true. So these stay plain
/// `AppEntity`/`IndexedEntity` conformances (a fully supported, permanent
/// path for anything outside the predefined domains) rather than adopting
/// a domain schema. `AskHermesIntent` / `OpenChatSessionIntent` in
/// AppIntents.swift are custom AppIntents for the same reason.
///
/// This is the correct call per Apple's own guidance — schemas cover
/// *common* categories; the framework is explicitly designed so intents
/// and entities outside those categories keep working as custom
/// AppIntents/AppEntity, with no loss of Siri/Spotlight/Shortcuts support.

// MARK: - Chat Session Entity

struct ChatSessionEntity: AppEntity, IndexedEntity {
    let id: String
    let title: String
    let lastMessagePreview: String
    let updatedAt: Date

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Hermes Chat"
    static var defaultQuery = ChatSessionEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(lastMessagePreview)",
            image: .init(systemName: "bubble.left.and.bubble.right")
        )
    }

    // IndexedEntity: contributes this entity to Spotlight's on-device
    // semantic index so Siri/Spotlight can resolve "that chat about X."
    var attributeSet: CSSearchableItemAttributeSetProxy {
        var attrs = CSSearchableItemAttributeSetProxy()
        attrs.title = title
        attrs.contentDescription = lastMessagePreview
        attrs.contentModificationDate = updatedAt
        return attrs
    }
}

struct ChatSessionEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ChatSessionEntity] {
        let all = await HermesSessionStore.shared.recentSessions()
        return all.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ChatSessionEntity] {
        await HermesSessionStore.shared.recentSessions()
    }
}

// MARK: - Skill Entity

struct HermesSkillEntity: AppEntity {
    let id: String
    let name: String
    let summary: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Hermes Skill"
    static var defaultQuery = HermesSkillEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(summary)")
    }
}

struct HermesSkillEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [HermesSkillEntity] {
        let all = await HermesSessionStore.shared.availableSkills()
        return all.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [HermesSkillEntity] {
        await HermesSessionStore.shared.availableSkills()
    }
}

// MARK: - Lightweight in-memory store backed by the Hermes API

/// Caches recent sessions/skills fetched from Hermes so entity queries
/// (used by Siri, Spotlight, and Shortcuts) don't block on network I/O
/// every time the system resolves an entity.
actor HermesSessionStore {
    static let shared = HermesSessionStore()

    private var sessions: [ChatSessionEntity] = []
    private var skills: [HermesSkillEntity] = []
    private var lastRefresh: Date?

    private init() {}

    func recentSessions() async -> [ChatSessionEntity] {
        await refreshIfNeeded()
        return sessions
    }

    func availableSkills() async -> [HermesSkillEntity] {
        await refreshIfNeeded()
        return skills
    }

    /// Called after a successful web UI chat load, or periodically from
    /// BackgroundRefresh, to keep the entity cache warm for Siri/Spotlight.
    func update(sessions: [ChatSessionEntity], skills: [HermesSkillEntity]) {
        self.sessions = sessions
        self.skills = skills
        self.lastRefresh = Date()
    }

    private func refreshIfNeeded() async {
        if let last = lastRefresh, Date().timeIntervalSince(last) < 300 { return }
        guard let base = ServerConfig.shared.baseURL else { return }

        async let sessionsTask = fetchSessions(base: base)
        async let skillsTask = fetchSkills(base: base)
        let (fetchedSessions, fetchedSkills) = await (sessionsTask, skillsTask)

        if let fetchedSessions { sessions = fetchedSessions }
        if let fetchedSkills { skills = fetchedSkills }
        lastRefresh = Date()
    }

    private func fetchSessions(base: URL) async -> [ChatSessionEntity]? {
        var request = URLRequest(url: base.appendingPathComponent("/api/hermes/sessions"))
        applyAuth(&request)
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        return json.compactMap { entry in
            guard let id = entry["id"] as? String, let title = entry["title"] as? String else { return nil }
            let preview = entry["lastMessage"] as? String ?? ""
            let updated = (entry["updatedAt"] as? String).flatMap(ISO8601DateFormatter().date(from:)) ?? Date()
            return ChatSessionEntity(id: id, title: title, lastMessagePreview: preview, updatedAt: updated)
        }
    }

    private func fetchSkills(base: URL) async -> [HermesSkillEntity]? {
        var request = URLRequest(url: base.appendingPathComponent("/api/hermes/skills"))
        applyAuth(&request)
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        return json.compactMap { entry in
            guard let id = entry["id"] as? String, let name = entry["name"] as? String else { return nil }
            return HermesSkillEntity(id: id, name: name, summary: entry["description"] as? String ?? "")
        }
    }

    private func applyAuth(_ request: inout URLRequest) {
        let token = ServerConfig.shared.hermesAuthToken
        if !token.isEmpty { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if !ServerConfig.shared.cfClientId.isEmpty {
            request.setValue(ServerConfig.shared.cfClientId, forHTTPHeaderField: "CF-Access-Client-Id")
            request.setValue(ServerConfig.shared.cfClientSecret, forHTTPHeaderField: "CF-Access-Client-Secret")
        }
    }
}
