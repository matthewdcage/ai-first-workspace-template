import WebKit

/// Injects Cloudflare Access and Hermes authentication into WKWebView sessions.
enum CFAuthInjector {

    /// Returns a JS snippet (safe to embed in a WKUserScript at atDocumentStart) that seeds
    /// localStorage with the Hermes token before any page script runs.  This ensures the
    /// WebSocket and SSE connections that open during Next.js hydration are authenticated.
    static func earlyTokenScript(token: String) -> String {
        let tokenLiteral = javaScriptLiteral(token)
        return """
        (function() {
            try {
                localStorage.setItem('hermes_token', \(tokenLiteral));
            } catch(e) {}
        })();
        """
    }

    /// Seeds the WKHTTPCookieStore before the first page load so the token cookie is present
    /// on the initial request and all subsequent same-origin requests (including WS upgrades).
    static func preSeedCookie(
        token: String,
        for url: URL,
        in dataStore: WKWebsiteDataStore,
        completion: (() -> Void)? = nil
    ) {
        var props: [HTTPCookiePropertyKey: Any] = [
            .name:    "hermes_token",
            .value:   token,
            .domain:  url.host ?? "",
            .path:    "/",
            .expires: Date().addingTimeInterval(60 * 60 * 24 * 30),
            HTTPCookiePropertyKey.sameSitePolicy: "Lax"
        ]
        // Only set Secure flag when the scheme is https
        if url.scheme == "https" { props[.secure] = true }
        if let cookie = HTTPCookie(properties: props) {
            dataStore.httpCookieStore.setCookie(cookie) {
                completion?()
            }
        } else {
            completion?()
        }
    }

    /// Called from didFinish as a belt-and-suspenders refresh (fires a storage event so any
    /// running React/Vue listener that missed the early seed can pick up the token).
    static func injectHermesToken(_ token: String, for url: URL, into webView: WKWebView) {
        var cookieProps: [HTTPCookiePropertyKey: Any] = [
            .name:    "hermes_token",
            .value:   token,
            .domain:  url.host ?? "",
            .path:    "/",
            .expires: Date().addingTimeInterval(60 * 60 * 24 * 30), // 30 days
            HTTPCookiePropertyKey.sameSitePolicy: "Lax"
        ]
        if url.scheme == "https" {
            cookieProps[.secure] = true
        }

        if let cookie = HTTPCookie(properties: cookieProps) {
            webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
        }

        let tokenLiteral = javaScriptLiteral(token)
        let js = """
        (function() {
            try {
                localStorage.setItem('hermes_token', \(tokenLiteral));
                window.dispatchEvent(new StorageEvent('storage', {
                    key: 'hermes_token',
                    newValue: \(tokenLiteral)
                }));
            } catch(e) {}
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private static func javaScriptLiteral(_ string: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: string, options: .fragmentsAllowed),
              let literal = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return literal
    }
}
