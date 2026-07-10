import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Wraps Apple's Foundation Models framework when it is available in the SDK
/// and on the current device. Older SDKs and unsupported devices fall back to
/// returning the original prompt, so Hermes remains usable everywhere.
@MainActor
final class FoundationModelsAdapter {
    static let shared = FoundationModelsAdapter()

    #if canImport(FoundationModels)
    private var sessionStorage: Any?
    #endif

    private init() {}

    var availabilityDescription: String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return "available"
            case .unavailable(.appleIntelligenceNotEnabled):
                return "apple_intelligence_disabled"
            case .unavailable(.deviceNotEligible):
                return "device_not_eligible"
            case .unavailable(.modelNotReady):
                return "model_not_ready"
            case .unavailable(_):
                return "unavailable"
            }
        }
        #endif
        return "sdk_unavailable"
    }

    /// Runs a prompt through the on-device Apple Foundation Model.
    /// Returns the original prompt when the framework or device is unavailable.
    func respond(to prompt: String) async -> String {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return "" }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return await respondWithFoundationModels(to: trimmedPrompt)
        }
        #endif

        return trimmedPrompt
    }

    /// Summarizes a long Hermes response for notification previews.
    func summarizeForNotification(_ text: String) async -> String {
        guard text.count > 160 else { return text }
        let prompt = """
        Summarize this Hermes agent response in one concise notification sentence.
        Preserve important numbers, dates, file names, and decisions exactly.

        Response:
        \(text)
        """
        return await respond(to: prompt)
    }

    /// Pre-processes a user message to improve clarity before it is sent to Hermes.
    func preprocess(userMessage: String) async -> String {
        guard userMessage.count > 80 else { return userMessage }
        let prompt = """
        Rewrite this user message for an AI agent. Keep the user's intent, constraints,
        names, numbers, and code identifiers unchanged. Return only the rewritten message.

        Message:
        \(userMessage)
        """
        return await respond(to: prompt)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func respondWithFoundationModels(to prompt: String) async -> String {
        switch SystemLanguageModel.default.availability {
        case .available:
            break
        default:
            return prompt
        }

        do {
            let activeSession = (sessionStorage as? LanguageModelSession) ?? makeSession()
            sessionStorage = activeSession
            let response = try await activeSession.respond(to: prompt)
            return response.content
        } catch {
            sessionStorage = nil
            return prompt
        }
    }

    @available(iOS 26.0, *)
    private func makeSession() -> LanguageModelSession {
        LanguageModelSession(instructions: """
        You are HermesApp's private on-device assistant layer. Keep responses concise,
        preserve factual details exactly, and avoid adding unsupported details. Use the
        user's wording and context as the source of truth.
        """)
    }
    #endif
}
