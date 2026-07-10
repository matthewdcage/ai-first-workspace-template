import Foundation
import CoreML
import NaturalLanguage

/// Classifies user input into Hermes skill categories using an on-device NL model.
/// Falls back gracefully when no model is bundled.
final class OnDeviceClassifier {
    static let shared = OnDeviceClassifier()

    /// Known Hermes skill names used as classification labels.
    /// Replace with your actual Hermes skill list or load dynamically from the API.
    static let knownSkills = [
        "web-search", "code-runner", "file-browser", "image-gen",
        "memory", "calendar", "email", "chat", "summarize", "translate"
    ]

    private init() {}

    /// Returns the most likely Hermes skill name for a given user message,
    /// using keyword heuristics when no CoreML model is available.
    func classify(message: String) -> String? {
        // Try CoreML model first if bundled
        if let label = classifyWithCoreML(message: message) { return label }
        // Fall back to keyword heuristics
        return heuristicClassify(message: message.lowercased())
    }

    private func classifyWithCoreML(message: String) -> String? {
        // Load HermesIntentClassifier.mlmodel from bundle if present
        guard let modelURL = Bundle.main.url(forResource: "HermesIntentClassifier", withExtension: "mlmodelc"),
              let model = try? NLModel(contentsOf: modelURL) else { return nil }
        return model.predictedLabel(for: message)
    }

    private func heuristicClassify(message: String) -> String? {
        let rules: [(keywords: [String], skill: String)] = [
            (["search", "google", "look up", "find info"], "web-search"),
            (["run", "execute", "compile", "code", "script"], "code-runner"),
            (["file", "upload", "download", "folder"], "file-browser"),
            (["image", "picture", "generate", "draw", "dall"], "image-gen"),
            (["remember", "memory", "recall", "what did"], "memory"),
            (["calendar", "schedule", "meeting", "event"], "calendar"),
            (["email", "send mail", "inbox", "draft"], "email"),
            (["summarize", "summary", "tldr", "brief"], "summarize"),
            (["translate", "in french", "in spanish", "in japanese"], "translate"),
        ]
        for rule in rules {
            if rule.keywords.contains(where: { message.contains($0) }) {
                return rule.skill
            }
        }
        return nil
    }
}
