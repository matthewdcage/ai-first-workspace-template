import WebKit
import UIKit
import AVFoundation

/// Handles messages posted from the Hermes web UI to Swift native code.
/// The web UI calls window.hermesNative.<method>(...) which is translated
/// into webkit.messageHandlers.<name>.postMessage(payload).
final class NativeBridge: NSObject, WKScriptMessageHandler {

    static let handlerNames = [
        "share",
        "speak",
        "stopSpeaking",
        "startListening",
        "stopListening",
        "requestFile",
        "scheduleNotification",
        "onDeviceAI",
        "preprocessMessage",
        "classifyIntent",
        "nativeStatus",
        "requestPermissions"
    ]

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
        case "stopSpeaking":
            SpeechBridge.shared.stopSpeaking()
        case "startListening":
            let callbackId = body["callbackId"] as? String ?? ""
            SpeechBridge.shared.webView = coordinator?.webView
            SpeechBridge.shared.startListening(callbackId: callbackId)
        case "stopListening":
            SpeechBridge.shared.stopListening()
        case "requestFile":
            let callbackId = body["callbackId"] as? String ?? ""
            handleFileRequest(callbackId: callbackId)
        case "scheduleNotification":
            let title = body["title"] as? String ?? "Hermes"
            let body2 = body["body"] as? String ?? ""
            let delay = (body["delay"] as? NSNumber)?.doubleValue ?? body["delay"] as? TimeInterval ?? 0
            NotificationManager.shared.schedule(title: title, body: body2, delay: delay)
        case "onDeviceAI":
            let prompt = body["prompt"] as? String ?? ""
            let callbackId = body["callbackId"] as? String ?? ""
            Task { await handleOnDeviceAI(prompt: prompt, callbackId: callbackId) }
        case "preprocessMessage":
            let message = body["message"] as? String ?? ""
            let callbackId = body["callbackId"] as? String ?? ""
            Task { await handlePreprocess(message: message, callbackId: callbackId) }
        case "classifyIntent":
            let message = body["message"] as? String ?? ""
            let callbackId = body["callbackId"] as? String ?? ""
            handleClassifyIntent(message: message, callbackId: callbackId)
        case "nativeStatus":
            let callbackId = body["callbackId"] as? String ?? ""
            Task { @MainActor in handleNativeStatus(callbackId: callbackId) }
        case "requestPermissions":
            let callbackId = body["callbackId"] as? String ?? ""
            Task { await handlePermissionRequest(callbackId: callbackId) }
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
                window.webkit.messageHandlers[name].postMessage(payload || {});
                return true;
            }
            return false;
        }
        let _callbacks = {};
        window._hermesCallback = function(id, result) {
            if (_callbacks[id]) {
                _callbacks[id].resolve(result);
                delete _callbacks[id];
            }
        };
        function callWithCallback(name, payload) {
            return new Promise(function(resolve, reject) {
                const id = Math.random().toString(36).slice(2);
                _callbacks[id] = { resolve: resolve, reject: reject };
                payload = payload || {};
                payload.callbackId = id;
                if (!post(name, payload)) {
                    delete _callbacks[id];
                    reject(new Error('Hermes native bridge is unavailable.'));
                }
            });
        }
        const api = {
            isNative: true,
            shareText: function(text) { post('share', {text: text}); },
            speak: function(text) { post('speak', {text: text}); },
            stopSpeaking: function() { post('stopSpeaking', {}); },
            startListening: function() { return callWithCallback('startListening', {}); },
            stopListening: function() { post('stopListening', {}); },
            requestFile: function() { return callWithCallback('requestFile', {}); },
            scheduleNotification: function(title, body, delay) {
                post('scheduleNotification', {title: title, body: body, delay: delay || 0});
            },
            onDeviceAI: function(prompt) { return callWithCallback('onDeviceAI', {prompt: prompt}); },
            preprocessMessage: function(message) { return callWithCallback('preprocessMessage', {message: message}); },
            classifyIntent: function(message) { return callWithCallback('classifyIntent', {message: message}); },
            nativeStatus: function() { return callWithCallback('nativeStatus', {}); },
            requestPermissions: function() { return callWithCallback('requestPermissions', {}); }
        };
        window.dispatchEvent(new Event('hermes:nativeReady'));
        return api;
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
        resolveCallback(callbackId: callbackId, result: result)
    }

    private func handlePreprocess(message: String, callbackId: String) async {
        let result = await FoundationModelsAdapter.shared.preprocess(userMessage: message)
        resolveCallback(callbackId: callbackId, result: result)
    }

    private func handleClassifyIntent(message: String, callbackId: String) {
        let skill = OnDeviceClassifier.shared.classify(message: message)
        resolveCallback(callbackId: callbackId, result: [
            "skill": skill as Any? ?? NSNull(),
            "source": skill == nil ? "none" : "on_device"
        ])
    }

    @MainActor
    private func handleNativeStatus(callbackId: String) {
        let status: [String: Any] = [
            "foundationModels": FoundationModelsAdapter.shared.availabilityDescription,
            "permissions": [
                "microphone": PermissionsManager.shared.microphone.bridgeValue,
                "speechRecognition": PermissionsManager.shared.speechRecognition.bridgeValue,
                "notifications": PermissionsManager.shared.notifications.bridgeValue,
                "photoLibrary": PermissionsManager.shared.photoLibrary.bridgeValue
            ]
        ]
        resolveCallback(callbackId: callbackId, result: status)
    }

    @MainActor
    private func handlePermissionRequest(callbackId: String) async {
        await PermissionsManager.shared.requestAll()
        handleNativeStatus(callbackId: callbackId)
    }

    private func resolveCallback(callbackId: String, result: Any) {
        guard !callbackId.isEmpty,
              let callbackLiteral = Self.jsonLiteral(callbackId),
              let resultLiteral = Self.jsonLiteral(result) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.coordinator?.webView?.evaluateJavaScript(
                "window._hermesCallback(\(callbackLiteral), \(resultLiteral))",
                completionHandler: nil
            )
        }
    }

    private static func jsonLiteral(_ value: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(value)
                || value is String
                || value is NSNumber
                || value is NSNull else {
            return nil
        }

        guard let data = try? JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
}

private enum AssociatedKeys {
    nonisolated(unsafe) static var delegate: UInt8 = 0
}

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

private extension PermissionsManager.Status {
    var bridgeValue: String {
        switch self {
        case .notDetermined:
            return "not_determined"
        case .granted:
            return "granted"
        case .denied:
            return "denied"
        }
    }
}
