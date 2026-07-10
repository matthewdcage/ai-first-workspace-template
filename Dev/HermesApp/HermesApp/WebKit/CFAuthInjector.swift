import WebKit

/// Injects Cloudflare Access and Hermes authentication into WKWebView sessions.
enum CFAuthInjector {

    /// Stores the Hermes JWT/token as a cookie and triggers re-authentication via JS.
    static func injectHermesToken(_ token: String, for url: URL, into webView: WKWebView) {
        // Set token as a cookie so Hermes's Koa session middleware picks it up
        let cookieProps: [HTTPCookiePropertyKey: Any] = [
            .name:    "hermes_token",
            .value:   token,
            .domain:  url.host ?? "",
            .path:    "/",
            .secure:  true,
            .expires: Date().addingTimeInterval(60 * 60 * 24 * 30) // 30 days
        ]
        if let cookie = HTTPCookie(properties: cookieProps) {
            webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
        }

        // Also set via JS localStorage as Hermes Studio stores the token there
        let js = """
        (function() {
            if (localStorage.getItem('hermes_token') !== '\(token)') {
                localStorage.setItem('hermes_token', '\(token)');
                // Trigger Vue reactivity by dispatching storage event
                window.dispatchEvent(new StorageEvent('storage', {
                    key: 'hermes_token',
                    newValue: '\(token)'
                }));
            }
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
}
