import WebKit
import SwiftUI

final class HermesWebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    weak var webView: WKWebView?
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
            if navigationAction.targetFrame?.isMainFrame == true,
               url.host == base.host,
               let clientId = config?.cfClientId, !clientId.isEmpty {
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

    // MARK: - WKUIDelegate (allow JS alert/confirm/prompt)

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else {
            completionHandler(); return
        }
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        root.present(alert, animated: true)
    }
}
