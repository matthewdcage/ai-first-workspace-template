import WebKit
import SwiftUI

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

    // MARK: - WKNavigationDelegate

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

        // Allow same-origin navigation and about:blank
        if url.host == base.host || url.scheme == "about" {
            // Re-inject CF headers if this is a main frame load to the Hermes origin
            // and the headers aren't already present — otherwise every navigation
            // to the same host re-triggers a load, causing an infinite loop.
            if navigationAction.targetFrame?.isMainFrame == true,
               url.host == base.host,
               let clientId = config?.cfClientId, !clientId.isEmpty,
               navigationAction.request.value(forHTTPHeaderField: "CF-Access-Client-Id") != clientId {
                var req = navigationAction.request
                req.setValue(clientId, forHTTPHeaderField: "CF-Access-Client-Id")
                req.setValue(config?.cfClientSecret, forHTTPHeaderField: "CF-Access-Client-Secret")
                webView.load(req)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        } else {
            // Open external links in Safari
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Auto-inject Hermes auth token into cookie store after page loads
        guard let token = config?.hermesAuthToken, !token.isEmpty,
              let url = webView.url else { return }

        CFAuthInjector.injectHermesToken(token, for: url, into: webView)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("[HermesApp] Navigation error: \(error.localizedDescription)")
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
}
