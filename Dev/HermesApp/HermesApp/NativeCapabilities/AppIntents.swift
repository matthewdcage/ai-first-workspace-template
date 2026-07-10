import AppIntents
import Foundation

// MARK: - Ask Hermes (Siri / Shortcuts)

struct AskHermesIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask Hermes"
    static var description = IntentDescription("Send a message to your self-hosted Hermes agent.")

    @Parameter(title: "Message", description: "What you want to ask Hermes")
    var message: String

    func perform() async throws -> some ProvidesDialog {
        let response = try await HermesAPIClient.shared.chat(message: message)
        return .result(dialog: IntentDialog(response))
    }
}

struct HermesShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskHermesIntent(),
            phrases: [
                "Ask Hermes \(\.$message)",
                "Tell Hermes \(\.$message)",
                "Send to Hermes \(\.$message)"
            ],
            shortTitle: "Ask Hermes",
            systemImageName: "bubble.left.and.bubble.right"
        )
    }
}

// MARK: - Hermes API client (used by App Intents — bypasses WKWebView)

final class HermesAPIClient {
    static let shared = HermesAPIClient()
    private init() {}

    func chat(message: String) async throws -> String {
        guard let base = ServerConfig.shared.baseURL else {
            throw URLError(.badURL)
        }
        let url = base.appendingPathComponent("/api/hermes/chat")
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let token = ServerConfig.shared.hermesAuthToken
        if !token.isEmpty { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if !ServerConfig.shared.cfClientId.isEmpty {
            request.setValue(ServerConfig.shared.cfClientId, forHTTPHeaderField: "CF-Access-Client-Id")
            request.setValue(ServerConfig.shared.cfClientSecret, forHTTPHeaderField: "CF-Access-Client-Secret")
        }

        let payload = ["message": message]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let reply = json["response"] as? String else {
            return "Hermes responded but the format was unexpected."
        }
        return reply
    }
}
