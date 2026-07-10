import UIKit

/// Handles incoming share sheet items — text or URLs shared into the Hermes app.
/// The shared content is deep-linked into the WKWebView as a pre-filled chat message.
enum ShareExtensionHandler {

    static func handle(extensionContext: NSExtensionContext?, in webView: WKWebView?) {
        guard let context = extensionContext,
              let item = context.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first else { return }

        if provider.hasItemConformingToTypeIdentifier("public.url") {
            provider.loadItem(forTypeIdentifier: "public.url", options: nil) { item, _ in
                let text = (item as? URL)?.absoluteString ?? ""
                Self.injectMessage(text, into: webView)
            }
        } else if provider.hasItemConformingToTypeIdentifier("public.plain-text") {
            provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { item, _ in
                let text = item as? String ?? ""
                Self.injectMessage(text, into: webView)
            }
        }
    }

    private static func injectMessage(_ text: String, into webView: WKWebView?) {
        guard let webView,
              let data = try? JSONSerialization.data(withJSONObject: text, options: .fragmentsAllowed),
              let jsonString = String(data: data, encoding: .utf8) else { return }
        DispatchQueue.main.async {
            webView.evaluateJavaScript(
                "window.hermesNative && window.dispatchEvent(new CustomEvent('hermes:shareInput', {detail: \(jsonString)}))",
                completionHandler: nil
            )
        }
    }
}
