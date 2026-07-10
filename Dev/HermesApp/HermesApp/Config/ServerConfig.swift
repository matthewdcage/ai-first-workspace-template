import Foundation
import Security
import Combine

/// Persists server URL and credentials in the iOS Keychain.
final class ServerConfig: ObservableObject {
    static let shared = ServerConfig()

    @Published var serverURL: String = ""
    @Published var cfClientId: String = ""
    @Published var cfClientSecret: String = ""
    @Published var hermesAuthToken: String = ""
    @Published var isConfigured: Bool = false

    private enum Key: String {
        case serverURL       = "hermes.serverURL"
        case cfClientId      = "hermes.cfClientId"
        case cfClientSecret  = "hermes.cfClientSecret"
        case hermesAuthToken = "hermes.authToken"
    }

    private init() { load() }

    func save() {
        set(serverURL, forKey: .serverURL)
        set(cfClientId, forKey: .cfClientId)
        set(cfClientSecret, forKey: .cfClientSecret)
        set(hermesAuthToken, forKey: .hermesAuthToken)
        isConfigured = !serverURL.isEmpty
    }

    func clear() {
        [Key.serverURL, .cfClientId, .cfClientSecret, .hermesAuthToken].forEach { delete(key: $0) }
        serverURL = ""; cfClientId = ""; cfClientSecret = ""; hermesAuthToken = ""
        isConfigured = false
    }

    var baseURL: URL? { URL(string: serverURL) }

    // MARK: - Keychain helpers

    private func load() {
        serverURL       = get(.serverURL) ?? ""
        cfClientId      = get(.cfClientId) ?? ""
        cfClientSecret  = get(.cfClientSecret) ?? ""
        hermesAuthToken = get(.hermesAuthToken) ?? ""
        isConfigured    = !serverURL.isEmpty
    }

    private func set(_ value: String, forKey key: Key) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key.rawValue as CFString
        ]
        var attrs: [CFString: Any] = [kSecValueData: data]
        if SecItemUpdate(query as CFDictionary, attrs as CFDictionary) == errSecItemNotFound {
            attrs[kSecClass]       = kSecClassGenericPassword
            attrs[kSecAttrAccount] = key.rawValue as CFString
            SecItemAdd(attrs as CFDictionary, nil)
        }
    }

    private func get(_ key: Key) -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
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
            kSecAttrAccount: key.rawValue as CFString
        ]
        SecItemDelete(query as CFDictionary)
    }
}
