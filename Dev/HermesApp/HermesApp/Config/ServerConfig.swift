import Foundation
import Security
import SwiftUI

struct FavoriteConnection: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var serverURL: String
    var createdAt: Date
    var lastUsedAt: Date?
    var lastSuccessfulAt: Date?

    var displayName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? serverURL : name
    }
}

struct ConnectionLogEntry: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case connection
        case session
    }

    let id: UUID
    let kind: Kind
    let title: String
    let serverURL: String
    let detail: String?
    let occurredAt: Date
    let wasSuccessful: Bool
}

@MainActor
final class ServerConfig: ObservableObject {
    private static let service = "au.aiadvantage.HermesApp"
    static let shared = ServerConfig()

    @Published var serverURL: String = ""
    @Published var cfClientId: String = ""
    @Published var cfClientSecret: String = ""
    @Published var hermesAuthToken: String = ""
    @Published var isConfigured: Bool = false

    /// Recently used server URLs (UserDefaults; not sensitive).
    @Published var recentURLs: [String] = []
    @Published var favoriteConnections: [FavoriteConnection] = []
    @Published var connectionLog: [ConnectionLogEntry] = []
    @Published var lastSuccessfulConnection: ConnectionLogEntry?

    private let recentURLsKey = "hermes.recentURLs"
    private let favoriteConnectionsKey = "hermes.favoriteConnections"
    private let connectionLogKey = "hermes.connectionLog"
    private let lastSuccessfulConnectionKey = "hermes.lastSuccessfulConnection"
    private let maxRecent = 5
    private let maxLogEntries = 25

    private enum Key: String {
        case serverURL       = "hermes.serverURL"
        case cfClientId      = "hermes.cfClientId"
        case cfClientSecret  = "hermes.cfClientSecret"
        case hermesAuthToken = "hermes.authToken"
    }

    private init(loadStoredValues: Bool = true) {
        if loadStoredValues {
            load()
        }
    }

    #if DEBUG
    static func preview(serverURL: String = "", authToken: String = "") -> ServerConfig {
        let config = ServerConfig(loadStoredValues: false)
        config.serverURL = serverURL
        config.hermesAuthToken = authToken
        config.isConfigured = !serverURL.isEmpty
        return config
    }
    #endif

    func save() {
        if let normalizedURL = Self.normalizedServerURLString(from: serverURL) {
            serverURL = normalizedURL
        }

        cfClientId = cfClientId.trimmingCharacters(in: .whitespacesAndNewlines)
        cfClientSecret = cfClientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        hermesAuthToken = hermesAuthToken.trimmingCharacters(in: .whitespacesAndNewlines)

        set(serverURL, forKey: .serverURL)
        set(cfClientId, forKey: .cfClientId)
        set(cfClientSecret, forKey: .cfClientSecret)
        set(hermesAuthToken, forKey: .hermesAuthToken)
        isConfigured = !serverURL.isEmpty
        addRecent(serverURL)
    }

    func saveAndMarkSuccessful() {
        save()
        recordConnectionSuccess()
    }

    /// Wipe all credentials and go back to setup.
    func clear() {
        [Key.serverURL, .cfClientId, .cfClientSecret, .hermesAuthToken].forEach { delete(key: $0) }
        serverURL = ""
        cfClientId = ""
        cfClientSecret = ""
        hermesAuthToken = ""
        isConfigured = false
    }

    /// Go back to setup WITHOUT clearing the URL so the user can edit it.
    func disconnect() {
        isConfigured = false
    }

    func removeRecent(_ url: String) {
        recentURLs.removeAll { $0 == url }
        UserDefaults.standard.set(recentURLs, forKey: recentURLsKey)
    }

    func favoriteCurrentConnection(named name: String) {
        guard let normalizedURL = Self.normalizedServerURLString(from: serverURL) else { return }
        serverURL = normalizedURL

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let index = favoriteConnections.firstIndex(where: { $0.serverURL == normalizedURL }) {
            favoriteConnections[index].name = trimmedName.isEmpty ? favoriteConnections[index].displayName : trimmedName
            favoriteConnections[index].lastUsedAt = Date()
        } else {
            favoriteConnections.insert(FavoriteConnection(
                id: UUID(),
                name: trimmedName.isEmpty ? defaultFavoriteName(for: normalizedURL) : trimmedName,
                serverURL: normalizedURL,
                createdAt: Date(),
                lastUsedAt: Date(),
                lastSuccessfulAt: nil
            ), at: 0)
        }
        persistFavorites()
    }

    func selectFavorite(_ favorite: FavoriteConnection) {
        serverURL = favorite.serverURL
        if let index = favoriteConnections.firstIndex(where: { $0.id == favorite.id }) {
            favoriteConnections[index].lastUsedAt = Date()
            moveFavoriteToFront(at: index)
        }
        persistFavorites()
    }

    func removeFavorite(_ favorite: FavoriteConnection) {
        favoriteConnections.removeAll { $0.id == favorite.id }
        persistFavorites()
    }

    func renameFavorite(_ favorite: FavoriteConnection, name: String) {
        guard let index = favoriteConnections.firstIndex(where: { $0.id == favorite.id }) else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        favoriteConnections[index].name = trimmedName.isEmpty ? defaultFavoriteName(for: favorite.serverURL) : trimmedName
        persistFavorites()
    }

    func recordConnectionSuccess(title: String? = nil) {
        guard let normalizedURL = Self.normalizedServerURLString(from: serverURL) else { return }
        serverURL = normalizedURL
        addRecent(normalizedURL)

        let displayTitle = title ?? favoriteConnections.first(where: { $0.serverURL == normalizedURL })?.displayName ?? defaultFavoriteName(for: normalizedURL)
        let entry = ConnectionLogEntry(
            id: UUID(),
            kind: .connection,
            title: displayTitle,
            serverURL: normalizedURL,
            detail: "Connection opened",
            occurredAt: Date(),
            wasSuccessful: true
        )
        lastSuccessfulConnection = entry
        if shouldAppendConnectionSuccess(for: normalizedURL) {
            addLogEntry(entry)
        }

        if let index = favoriteConnections.firstIndex(where: { $0.serverURL == normalizedURL }) {
            favoriteConnections[index].lastUsedAt = Date()
            favoriteConnections[index].lastSuccessfulAt = Date()
            moveFavoriteToFront(at: index)
            persistFavorites()
        }
        persistLastSuccessfulConnection()
    }

    func recordSession(title: String?, url: URL?) {
        guard let url else { return }
        let absoluteString = url.absoluteString
        guard !absoluteString.isEmpty else { return }

        let entry = ConnectionLogEntry(
            id: UUID(),
            kind: .session,
            title: title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Hermes session",
            serverURL: serverURL,
            detail: absoluteString,
            occurredAt: Date(),
            wasSuccessful: true
        )
        addLogEntry(entry)
    }

    var baseURL: URL? { URL(string: serverURL) }

    var authenticationHeaders: [String: String] {
        var headers: [String: String] = [:]

        let token = hermesAuthToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !token.isEmpty {
            headers["Authorization"] = "Bearer \(token)"
        }

        let clientId = cfClientId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clientId.isEmpty {
            headers["CF-Access-Client-Id"] = clientId
            headers["CF-Access-Client-Secret"] = cfClientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return headers
    }

    static func normalizedServerURLString(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard var components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host,
              !host.isEmpty else {
            return nil
        }

        components.scheme = scheme
        components.query = nil
        components.fragment = nil

        guard var normalized = components.url?.absoluteString else { return nil }
        while normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        return normalized
    }

    func authenticatedRequest(path: String, timeoutInterval: TimeInterval = 30) -> URLRequest? {
        guard let url = baseURL?.appendingHermesPath(path) else { return nil }
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        applyAuthentication(to: &request)
        return request
    }

    func applyAuthentication(to request: inout URLRequest) {
        for (header, value) in authenticationHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }
    }

    // MARK: - Keychain helpers

    private func load() {
        serverURL       = get(.serverURL) ?? ""
        cfClientId      = get(.cfClientId) ?? ""
        cfClientSecret  = get(.cfClientSecret) ?? ""
        hermesAuthToken = get(.hermesAuthToken) ?? ""
        isConfigured    = !serverURL.isEmpty
        recentURLs      = UserDefaults.standard.stringArray(forKey: recentURLsKey) ?? []
        favoriteConnections = decode([FavoriteConnection].self, forKey: favoriteConnectionsKey) ?? []
        connectionLog = decode([ConnectionLogEntry].self, forKey: connectionLogKey) ?? []
        lastSuccessfulConnection = decode(ConnectionLogEntry.self, forKey: lastSuccessfulConnectionKey)
    }

    private func addRecent(_ url: String) {
        guard !url.isEmpty else { return }
        recentURLs.removeAll { $0 == url }
        recentURLs.insert(url, at: 0)
        if recentURLs.count > maxRecent { recentURLs = Array(recentURLs.prefix(maxRecent)) }
        UserDefaults.standard.set(recentURLs, forKey: recentURLsKey)
    }

    private func addLogEntry(_ entry: ConnectionLogEntry) {
        connectionLog.insert(entry, at: 0)
        if connectionLog.count > maxLogEntries {
            connectionLog = Array(connectionLog.prefix(maxLogEntries))
        }
        encode(connectionLog, forKey: connectionLogKey)
    }

    private func shouldAppendConnectionSuccess(for serverURL: String) -> Bool {
        guard let latest = connectionLog.first else { return true }
        guard latest.kind == .connection, latest.serverURL == serverURL else { return true }
        return Date().timeIntervalSince(latest.occurredAt) > 30
    }

    private func moveFavoriteToFront(at index: Int) {
        guard favoriteConnections.indices.contains(index), index != 0 else { return }
        let item = favoriteConnections.remove(at: index)
        favoriteConnections.insert(item, at: 0)
    }

    private func persistFavorites() {
        encode(favoriteConnections, forKey: favoriteConnectionsKey)
    }

    private func persistLastSuccessfulConnection() {
        encode(lastSuccessfulConnection, forKey: lastSuccessfulConnectionKey)
    }

    private func defaultFavoriteName(for urlString: String) -> String {
        guard let host = URL(string: urlString)?.host else { return "Hermes" }
        return host
    }

    private func encode<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func set(_ value: String, forKey key: Key) {
        guard !value.isEmpty else {
            delete(key: key)
            return
        }

        guard let data = value.data(using: .utf8) else { return }
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: key.rawValue as CFString
        ]
        var attrs: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            attrs[kSecClass]       = kSecClassGenericPassword
            attrs[kSecAttrService] = Self.service
            attrs[kSecAttrAccount] = key.rawValue as CFString
            let addStatus = SecItemAdd(attrs as CFDictionary, nil)
            if addStatus != errSecSuccess { print("[Keychain] Add failed: \(addStatus)") }
        } else if status != errSecSuccess {
            print("[Keychain] Update failed: \(status)")
        }
    }

    private func get(_ key: Key) -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: key.rawValue as CFString,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func delete(key: Key) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: key.rawValue as CFString
        ]
        SecItemDelete(query as CFDictionary)
    }
}

extension URL {
    func appendingHermesPath(_ path: String) -> URL {
        path
            .split(separator: "/")
            .map(String.init)
            .reduce(self) { partialURL, component in
                partialURL.appendingPathComponent(component)
            }
    }

    func isSameOrigin(as otherURL: URL) -> Bool {
        scheme?.lowercased() == otherURL.scheme?.lowercased()
            && host?.lowercased() == otherURL.host?.lowercased()
            && effectivePort == otherURL.effectivePort
    }

    private var effectivePort: Int? {
        if let port { return port }
        switch scheme?.lowercased() {
        case "http": return 80
        case "https": return 443
        default: return nil
        }
    }
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
