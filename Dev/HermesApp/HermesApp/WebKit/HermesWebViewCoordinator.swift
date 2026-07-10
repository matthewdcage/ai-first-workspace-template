@preconcurrency import WebKit
import SwiftUI

struct WebViewSnapshot: Sendable {
    let title: String?
    let url: URL?
    let isLoading: Bool
    let estimatedProgress: Double
    let canGoBack: Bool
    let canGoForward: Bool
}

@MainActor
final class HermesWebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    /// The webview of the most recently created coordinator — there is
    /// exactly one live WebView instance in practice, so this gives
    /// non-SwiftUI call sites (AppDelegate notification handling, Spotlight
    /// deep links) a way to reach it without threading a reference through.
    static weak var activeWebView: WKWebView?

    weak var webView: WKWebView? {
        didSet { Self.activeWebView = webView }
    }
    var config: ServerConfig?
    var onLoadStarted: (() -> Void)?
    var onLoadFinished: (() -> Void)?
    var onLoadFailed: ((String) -> Void)?
    var onStateChanged: ((WebViewSnapshot) -> Void)?
    private var observations: [NSKeyValueObservation] = []

    func observe(webView: WKWebView) {
        observations = [
            webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self, weak webView] _, _ in
                Task { @MainActor in
                    guard let webView else { return }
                    self?.publishSnapshot(for: webView)
                }
            },
            webView.observe(\.title, options: [.initial, .new]) { [weak self, weak webView] _, _ in
                Task { @MainActor in
                    guard let webView else { return }
                    self?.publishSnapshot(for: webView)
                }
            },
            webView.observe(\.url, options: [.initial, .new]) { [weak self, weak webView] _, _ in
                Task { @MainActor in
                    guard let webView else { return }
                    self?.publishSnapshot(for: webView)
                }
            },
            webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self, weak webView] _, _ in
                Task { @MainActor in
                    guard let webView else { return }
                    self?.publishSnapshot(for: webView)
                }
            },
            webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self, weak webView] _, _ in
                Task { @MainActor in
                    guard let webView else { return }
                    self?.publishSnapshot(for: webView)
                }
            },
            webView.observe(\.isLoading, options: [.initial, .new]) { [weak self, weak webView] _, _ in
                Task { @MainActor in
                    guard let webView else { return }
                    self?.publishSnapshot(for: webView)
                }
            }
        ]
        publishSnapshot(for: webView)
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        onLoadStarted?()
        publishSnapshot(for: webView)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url,
              let base = config?.baseURL else {
            decisionHandler(.allow)
            return
        }

        // Allow same-origin navigation and about:blank.
        if url.isSameOrigin(as: base) || url.scheme == "about" {
            // Re-inject auth headers if this is a main-frame load to the Hermes origin
            // and the headers aren't already present — otherwise every navigation
            // to the same host re-triggers a load, causing an infinite loop.
            if navigationAction.targetFrame?.isMainFrame == true,
               url.isSameOrigin(as: base),
               let headers = config?.authenticationHeaders,
               headers.contains(where: { navigationAction.request.value(forHTTPHeaderField: $0.key) != $0.value }) {
                var req = navigationAction.request
                headers.forEach { req.setValue($0.value, forHTTPHeaderField: $0.key) }
                webView.load(req)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        } else {
            // Handle external links and special schemes
            if let scheme = url.scheme?.lowercased() {
                if ["mailto", "tel", "sms"].contains(scheme) {
                    UIApplication.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }
            }
            // If this is a new-window request (targetFrame == nil), open externally
            if navigationAction.targetFrame == nil {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        publishSnapshot(for: webView)
        onLoadFinished?()
        guard let token = config?.hermesAuthToken, !token.isEmpty,
              let url = webView.url else { return }
        CFAuthInjector.injectHermesToken(token, for: url, into: webView)
        DeepLinkManager.shared.consumeIfNeeded(using: webView)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard !isCancelledNavigation(error) else { return }
        let msg = error.localizedDescription
        print("[HermesApp] Navigation error: \(msg)")
        publishSnapshot(for: webView)
        onLoadFailed?(msg)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard !isCancelledNavigation(error) else { return }
        let msg = error.localizedDescription
        print("[HermesApp] Provisional navigation error: \(msg)")
        publishSnapshot(for: webView)
        onLoadFailed?(msg)
    }

    // MARK: - WKUIDelegate (allow JS alert/confirm/prompt, native file upload)

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        guard let topVC = Self.topViewController() else {
            completionHandler(); return
        }
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        topVC.present(alert, animated: true)
    }

    @available(iOS 18.4, *)
    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping ([URL]?) -> Void
    ) {
        guard let topVC = Self.topViewController() else {
            completionHandler(nil); return
        }
        WKWebView.handleFileUpload(parameters: parameters, from: topVC, completion: completionHandler)
    }

    /// Walks the presented-view-controller chain so alerts/pickers don't
    /// silently fail to present when another sheet is already on screen.
    static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              var top = scene.windows.first?.rootViewController else { return nil }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }

    private func publishSnapshot(for webView: WKWebView) {
        let snapshot = WebViewSnapshot(
            title: webView.title,
            url: webView.url,
            isLoading: webView.isLoading,
            estimatedProgress: webView.estimatedProgress,
            canGoBack: webView.canGoBack,
            canGoForward: webView.canGoForward
        )

        DispatchQueue.main.async { [weak self] in
            self?.onStateChanged?(snapshot)
        }
    }

    private func isCancelledNavigation(_ error: Error) -> Bool {
        (error as NSError).code == NSURLErrorCancelled
    }
}

/// Buffers deep links from notifications, Spotlight, App Intents, and Handoff
/// until the WebView is ready to receive navigation.
@MainActor
final class DeepLinkManager {
    static let shared = DeepLinkManager()

    private var pendingURL: URL?

    private init() {}

    func storeOrLoad(url: URL, webView: WKWebView?) {
        if let webView {
            webView.load(URLRequest(url: url))
        } else {
            pendingURL = url
        }
    }

    func consumeIfNeeded(using webView: WKWebView?) {
        guard let url = pendingURL, let webView else { return }
        pendingURL = nil
        webView.load(URLRequest(url: url))
    }
}
