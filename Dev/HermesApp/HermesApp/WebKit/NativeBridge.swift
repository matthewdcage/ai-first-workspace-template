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
            guard let topVC = HermesWebViewCoordinator.topViewController() else { return }
            let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
            topVC.present(vc, animated: true)
        }
    }

    private func handleFileRequest(callbackId: String) {
        DispatchQueue.main.async {
            guard let topVC = HermesWebViewCoordinator.topViewController() else { return }
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
            picker.allowsMultipleSelection = false
            let handler = FilePickerDelegate(callbackId: callbackId, webView: self.coordinator?.webView)
            picker.delegate = handler
            objc_setAssociatedObject(picker, &AssociatedKeys.delegate, handler, .OBJC_ASSOCIATION_RETAIN)
            topVC.present(picker, animated: true)
        }
    }

    private func handleOnDeviceAI(prompt: String, callbackId: String) async {
        let result = await FoundationModelsAdapter.shared.respond(to: prompt)
        guard let data = try? JSONSerialization.data(withJSONObject: result, options: .fragmentsAllowed),
              let jsonString = String(data: data, encoding: .utf8) else { return }
        await MainActor.run {
            coordinator?.webView?.evaluateJavaScript(
                "window._hermesCallback('\(callbackId)', \(jsonString))",
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
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer { if shouldStopAccessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }

        let payload: [String: String] = ["name": url.lastPathComponent, "data": data.base64EncodedString()]
        guard let payloadData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: payloadData, encoding: .utf8) else { return }

        webView?.evaluateJavaScript(
            "window._hermesCallback('\(callbackId)', \(jsonString))",
            completionHandler: nil
        )
    }
}
