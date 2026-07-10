import Foundation

/// Wraps Apple's on-device Foundation Models framework (iOS 18.1+).
/// Falls back to a pass-through on unsupported devices.
///
/// Requires: Xcode 16.1+, iOS 18.1+ deployment target, and the
/// com.apple.developer.foundation-models entitlement.
@MainActor
final class FoundationModelsAdapter {
    static let shared = FoundationModelsAdapter()
    private init() {}

    /// Runs a prompt through the on-device Apple Intelligence model.
    /// Returns the raw response string, or the original prompt on failure.
    func respond(to prompt: String) async -> String {
        // FoundationModels is conditionally available — gate on runtime check
        if #available(iOS 18.1, *) {
            return await runFoundationModel(prompt: prompt)
        }
        return prompt
    }

    /// Summarize a long Hermes response for notification previews.
    func summarizeForNotification(_ text: String) async -> String {
        let instruction = "Summarize this AI agent response in one sentence for a push notification: \(text)"
        return await respond(to: instruction)
    }

    /// Pre-process a user message — clean up, detect intent, improve clarity.
    func preprocess(userMessage: String) async -> String {
        guard userMessage.count > 80 else { return userMessage }
        let instruction = "Rephrase this message to be clear and concise for an AI agent: \(userMessage)"
        return await respond(to: instruction)
    }

    @available(iOS 18.1, *)
    private func runFoundationModel(prompt: String) async -> String {
        // Dynamic import guard: FoundationModels may not be available even on iOS 18.1
        // on devices without Apple Intelligence (A17 Pro / M-series required).
        // We use NSClassFromString to avoid a hard link on older devices.
        guard let sessionClass = NSClassFromString("FMLanguageModelSession") as? NSObject.Type else {
            return prompt // device doesn't support Apple Intelligence
        }
        let session = sessionClass.init()
        let sel = NSSelectorFromString("respondToPrompt:completionHandler:")
        guard session.responds(to: sel) else {
            return prompt
        }
        return await withCheckedContinuation { continuation in
            typealias Handler = @convention(block) (String?, Error?) -> Void
            let block: Handler = { result, _ in
                continuation.resume(returning: result ?? prompt)
            }
            // performSelector(with:with:) assumes an object-returning method and can
            // crash (mis-reads/retains a bogus return value) on a void-returning
            // selector. Resolve the IMP and invoke it through a typed C function
            // pointer instead, which matches the real signature exactly.
            typealias MethodType = @convention(c) (NSObject, Selector, String, @escaping Handler) -> Void
            let imp = session.method(for: sel)
            let function = unsafeBitCast(imp, to: MethodType.self)
            function(session, sel, prompt, block)
        }
    }
}
