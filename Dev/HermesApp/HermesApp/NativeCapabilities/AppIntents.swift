import AppIntents
import Foundation

// MARK: - Ask Hermes (Siri / Shortcuts)

struct AskHermesIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask Hermes"
    static let description = IntentDescription("Send a message to your self-hosted Hermes agent.")

    @Parameter(title: "Message", description: "What you want to ask Hermes")
    var message: String

    func perform() async throws -> some ProvidesDialog {
        let response = try await HermesAPIClient.shared.chat(message: message)
        return .result(dialog: IntentDialog(stringLiteral: response))
    }
}

// MARK: - Open Chat Session (Siri / Spotlight / Shortcuts)

struct OpenChatSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Hermes Chat"
    static let description = IntentDescription("Open a specific Hermes chat session.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Chat")
    var session: ChatSessionEntity

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            HandoffManager.makeChatActivity(sessionId: session.id, title: session.title).becomeCurrent()
        }
        if let base = await ServerConfig.shared.baseURL {
            let url = base.appendingHermesPath("chat/\(session.id)")
            await MainActor.run {
                _ = HermesWebViewCoordinator.activeWebView?.load(URLRequest(url: url))
            }
        }
        return .result()
    }
}

struct HermesShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskHermesIntent(),
            phrases: [
                "Ask \(.applicationName)",
                "Talk to \(.applicationName)",
                "Send a message to \(.applicationName)"
            ],
            shortTitle: "Ask Hermes",
            systemImageName: "bubble.left.and.bubble.right"
        )
        AppShortcut(
            intent: OpenChatSessionIntent(),
            phrases: [
                "Open \(\.$session) in \(.applicationName)",
                "Continue \(\.$session) in \(.applicationName)"
            ],
            shortTitle: "Open Hermes Chat",
            systemImageName: "clock.arrow.circlepath"
        )
    }
}

// MARK: - Hermes API client (used by App Intents — bypasses WKWebView)

final class HermesAPIClient: @unchecked Sendable {
    static let shared = HermesAPIClient()
    private init() {}

    func chat(message: String) async throws -> String {
        guard var request = await ServerConfig.shared.authenticatedRequest(
            path: "api/hermes/chat",
            timeoutInterval: 30
        ) else {
            throw URLError(.badURL)
        }
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ["message": message]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(localized: "api.unexpected_response")
        }

        return (json["response"] as? String)
            ?? (json["reply"] as? String)
            ?? (json["message"] as? String)
            ?? String(localized: "api.unexpected_response")
    }
}
