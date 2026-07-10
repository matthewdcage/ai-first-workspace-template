import Foundation
import AppIntents
import Vision
#if canImport(VisualIntelligence)
import VisualIntelligence
#endif

/// Integrates Hermes with Apple's Visual Intelligence (WWDC26, shipping
/// iOS/macOS 27): a user points Camera (or selects on-screen content on
/// Mac/iPad) and the system asks every installed app "does any of your
/// content match this?" Unlike Assistant Schema domains (see
/// Search/HermesEntities.swift), this is domain-agnostic — any app's
/// entities are eligible — which is why it applies directly to our existing
/// ChatSessionEntity / HermesSkillEntity.
///
/// Verified against the WWDC26 session 297 ("Best practices for
/// integrating visual intelligence in your app") transcript, which includes
/// the full worked example this file follows: `SemanticContentDescriptor`
/// exposes `pixelBuffer: CVReadOnlyPixelBuffer?`, apps implement
/// `IntentValueQuery.values(for:)`, and the entry intent is annotated
/// `@AppIntent(schema: .visualIntelligence.semanticContentSearch)`.
/// Still wrapped in `#if canImport(VisualIntelligence)` so it compiles to
/// nothing on any SDK earlier than 27.
#if canImport(VisualIntelligence)

/// Resolves a captured camera frame / on-screen selection to matching
/// Hermes sessions, so Visual Intelligence can offer "open in Hermes" for
/// content the user points their camera at — e.g. a whiteboard photo of a
/// task list that has text overlapping a past agent conversation's title.
///
/// Uses on-device OCR (`VNRecognizeTextRequest`) rather than the
/// feature-print/image-similarity approach Apple's own sample uses for
/// album art: Hermes sessions are text content, not images, so matching by
/// recognized text against cached session titles is the correct technique
/// for this domain (image feature prints are for "does this photo look
/// like that photo," which isn't the question here).
struct HermesSemanticContentQuery: IntentValueQuery {
    func values(for input: SemanticContentDescriptor) async throws -> [ChatSessionEntity] {
        guard let pixelBuffer = input.pixelBuffer else { return [] }

        let recognizedText = try await recognizeText(in: pixelBuffer)
        let sessions = await HermesSessionStore.shared.recentSessions()
        guard !recognizedText.isEmpty else { return [] }

        return sessions.filter { session in
            recognizedText.contains { line in
                session.title.localizedCaseInsensitiveContains(line)
                    || line.localizedCaseInsensitiveContains(session.title)
            }
        }
    }

    private func recognizeText(in pixelBuffer: CVReadOnlyPixelBuffer) async throws -> [String] {
        var cgImage: CGImage?
        _ = pixelBuffer.withUnsafeBuffer { buffer in
            VTCreateCGImageFromCVPixelBuffer(buffer, options: nil, imageOut: &cgImage)
        }
        guard let cgImage else { return [] }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])

        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    }
}

/// The intent Visual Intelligence invokes with the semantic content it
/// captured. The `semanticContentSearch` schema auto-supplies
/// `semanticContent` — no manual camera-pipeline wiring needed.
@AppIntent(schema: .visualIntelligence.semanticContentSearch)
struct HermesSemanticContentSearchIntent: AppIntent {
    static let title: LocalizedStringResource = "Find in Hermes"
    static let openAppWhenRun: Bool = true

    var semanticContent: SemanticContentDescriptor

    func perform() async throws -> some IntentResult {
        let matches = try await HermesSemanticContentQuery().values(for: semanticContent)
        guard let base = ServerConfig.shared.baseURL, let first = matches.first else {
            return .result()
        }
        // Land on the strongest match; Visual Intelligence's result list in
        // its own UI already lets the user pick among all `matches` before
        // this intent runs, per Apple's sample (OpenIntent pattern).
        let url = base.appendingPathComponent("/chat/\(first.id)")
        await MainActor.run { HermesWebViewCoordinator.activeWebView?.load(URLRequest(url: url)) }
        return .result()
    }
}

#endif
