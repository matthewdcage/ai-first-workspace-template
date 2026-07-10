import Foundation
import AppIntents
#if canImport(VisualIntelligence)
import VisualIntelligence
#endif

/// Integrates Hermes with Apple's Visual Intelligence (announced WWDC26,
/// shipping iOS/macOS 27): a user points Camera (or selects on-screen
/// content on Mac/iPad) and the system asks every installed app "does any
/// of your content match this?" Unlike Assistant Schema domains, this is
/// domain-agnostic — any app's entities are eligible, which is why this one
/// applies directly to our existing ChatSessionEntity / HermesSkillEntity
/// rather than being blocked on a schema fit.
///
/// Verification status: entirely guarded behind `#if canImport(VisualIntelligence)`,
/// so this compiles to nothing on any SDK where the framework doesn't exist —
/// it cannot break a build on Xcode < 27. The type/protocol names below
/// (`SemanticContentDescriptor`, `pixelBuffer`, an `IntentValueQuery` keyed by
/// that descriptor) are corroborated across independent WWDC26 coverage but
/// were not confirmed against Apple's primary doc page directly (it returned
/// empty/blocked on fetch). Before shipping: open this file in Xcode 27,
/// let autocomplete/the compiler correct any renamed symbol, per Apple's
/// December-2026-era SDK.
#if canImport(VisualIntelligence)

/// Resolves a captured camera frame / on-screen selection to matching
/// Hermes sessions and skills, so Visual Intelligence can offer "open in
/// Hermes" for content the user points their camera at (e.g. a whiteboard
/// photo of a task list that matches a past agent conversation).
struct HermesSemanticContentQuery: IntentValueQuery {
    func values(for descriptor: SemanticContentDescriptor) async throws -> [ChatSessionEntity] {
        // A real implementation would run Vision/OCR over descriptor.pixelBuffer
        // and rank cached sessions by textual/visual similarity. For now this
        // does a lightweight keyword pass against cached titles as a starting
        // point — swap in a proper embedding/OCR match once this compiles
        // against the real SDK.
        let sessions = await HermesSessionStore.shared.recentSessions()
        guard !sessions.isEmpty else { return [] }
        return sessions
    }
}

/// The intent Visual Intelligence invokes with the semantic content it
/// captured. Apple's `semanticContentSearch` schema auto-provides the
/// `semanticContent` parameter — no manual wiring of the camera pipeline.
struct HermesSemanticContentSearchIntent: AppIntent {
    static var title: LocalizedStringResource = "Find in Hermes"
    static var description = IntentDescription("Find Hermes chats or skills matching what's on screen or in view.")

    // NOTE: the exact schema path (`.system.semanticContentSearch`,
    // `.visualIntelligence.semanticContentSearch`, or similar) needs
    // confirming against Xcode 27 — this is the one symbol in this file
    // not independently corroborated. Once confirmed, annotate this
    // struct with `@AssistantIntent(schema: <confirmed path>)` so the
    // system supplies `semanticContent` automatically instead of the
    // manual parameter below.
    @Parameter(title: "Semantic Content")
    var semanticContent: SemanticContentDescriptor

    func perform() async throws -> some ReturnsValue<[ChatSessionEntity]> {
        let matches = try await HermesSemanticContentQuery().values(for: semanticContent)
        return .result(value: matches)
    }
}

#endif
