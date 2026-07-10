import WebKit
import UIKit
import AVFoundation

/// Handles messages posted from the Hermes web UI to Swift native code.
/// The web UI calls window.hermesNative.<method>(...) which is translated
/// into webkit.messageHandlers.<name>.postMessage(payload).
final class NativeBridge: NSObject, WKScriptMessageHandler {

    static let handlerNames = ["share", "speak", "requestFile", "scheduleNotification", "onDeviceAI"]

    weak var coordinator: HermesWebViewCoordinator?

    init(coordinator: HermesWebViewCoordinator) {
        self.coordinator = coordinator
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let body = message.body as? [String: Any] else { return }

        switch message.name {
        case "share":
            if let text = body["text"] as? String { handleShare(text: text) }
        case "speak":
            if let text = body["text"] as? String { SpeechBridge.shared.speak(text) }
        case "requestFile":
            let callbackId = body["callbackId"] as? String ?? ""
            handleFileRequest(callbackId: callbackId)
        case "scheduleNotification":
            let title = body["title"] as? String ?? "Hermes"
            let body2 = body["body"] as? String ?? ""
            let delay = body["delay"] as? TimeInterval ?? 0
            NotificationManager.shared.schedule(title: title, body: body2, delay: delay)
        case "onDeviceAI":
            let prompt = body["prompt"] as? String ?? ""
            let callbackId = body["callbackId"] as? String ?? ""
            Task { await handleOnDeviceAI(prompt: prompt, callbackId: callbackId) }
        default:
            break
        }
    }

    // MARK: - Injected JavaScript

    /// Defines window.hermesNative with ergonomic methods the Vue app can call.
    static var injectedJavaScript: String { """
    window.hermesNative = (function() {
        function post(name, payload) {
            if (window.webkit && window.webkit.messageHandlers[name]) {
                window.webkit.messageHandlers[name].postMessage(payload);
            }
        }
        let _callbacks = {};
        window._hermesCallback = function(id, result) {
            if (_callbacks[id]) { _callbacks[id](result); delete _callbacks[id]; }
        };
        function callWithCallback(name, payload) {
            return new Promise(function(resolve) {
                const id = Math.random().toString(36).slice(2);
                _callbacks[id] = resolve;
                payload.callbackId = id;
                post(name, payload);
            });
        }
        return {
            isNative: true,
            shareText: function(text) { post('share', {text: text}); },
            speak: function(text) { post('speak', {text: text}); },
            requestFile: function() { return callWithCallback('requestFile', {}); },
            scheduleNotification: function(title, body, delay) {
                post('scheduleNotification', {title: title, body: body, delay: delay || 0});
            },
            onDeviceAI: function(prompt) { return callWithCallback('onDeviceAI', {prompt: prompt}); }
        };
    })();
    """ }

    // MARK: - Handlers

    private func handleShare(text: String) {
        DispatchQueue.main.async {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let root = scene.windows.first?.rootViewController else { return }
            let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
            root.present(vc, animated: true)
        }
    }

    private func handleFileRequest(callbackId: String) {
        DispatchQueue.main.async {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let root = scene.windows.first?.rootViewController else { return }
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
            picker.allowsMultipleSelection = false
            let handler = FilePickerDelegate(callbackId: callbackId, webView: self.coordinator?.webView)
            picker.delegate = handler
            objc_setAssociatedObject(picker, &AssociatedKeys.delegate, handler, .OBJC_ASSOCIATION_RETAIN)
            root.present(picker, animated: true)
        }
    }

    private func handleOnDeviceAI(prompt: String, callbackId: String) async {
        let result = await FoundationModelsAdapter.shared.respond(to: prompt)
        await MainActor.run {
            let escaped = result.replacingOccurrences(of: "\\", with: "\\\\")
                                .replacingOccurrences(of: "'", with: "\\'")
            coordinator?.webView?.evaluateJavaScript(
                "window._hermesCallback('\(callbackId)', '\(escaped)')",
                completionHandler: nil
            )
        }
    }
}

private enum AssociatedKeys { static var delegate = "filePickerDelegate" }

// Separate class to hold UIDocumentPickerDelegate reference alive
private final class FilePickerDelegate: NSObject, UIDocumentPickerDelegate {
    let callbackId: String
    weak var webView: WKWebView?

    init(callbackId: String, webView: WKWebView?) {
        self.callbackId = callbackId
        self.webView = webView
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url) else { return }
        let b64 = data.base64EncodedString()
        let name = url.lastPathComponent
        let escaped = b64.replacingOccurrences(of: "\\", with: "\\\\")
        webView?.evaluateJavaScript(
            "window._hermesCallback('\(callbackId)', {name: '\(name)', data: '\(escaped)'})",
            completionHandler: nil
        )
    }
}
