import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    @EnvironmentObject var config: ServerConfig

    func makeCoordinator() -> HermesWebViewCoordinator {
        HermesWebViewCoordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let wkConfig = WKWebViewConfiguration()

        // Allow inline media & audio without requiring user gesture
        wkConfig.allowsInlineMediaPlayback = true
        wkConfig.mediaTypesRequiringUserActionForPlayback = []

        // Register native message handlers
        let bridge = NativeBridge(coordinator: context.coordinator)
        for name in NativeBridge.handlerNames {
            wkConfig.userContentController.add(bridge, name: name)
        }

        // Inject hermesNative JS bridge object before page loads
        let bridgeScript = WKUserScript(
            source: NativeBridge.injectedJavaScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        wkConfig.userContentController.addUserScript(bridgeScript)

        // Mobile viewport injection
        let viewportScript = WKUserScript(
            source: """
            var meta = document.querySelector('meta[name="viewport"]');
            if (!meta) {
                meta = document.createElement('meta');
                meta.name = 'viewport';
                document.head.appendChild(meta);
            }
            meta.content = 'width=device-width, initial-scale=1, viewport-fit=cover';
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        wkConfig.userContentController.addUserScript(viewportScript)

        let webView = WKWebView(frame: .zero, configuration: wkConfig)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.customUserAgent = "HermesApp/1.0 (iPhone; iOS 18; WebWrapper)"
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic

        context.coordinator.webView = webView
        context.coordinator.config = config

        load(webView: webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    private func load(webView: WKWebView) {
        guard let url = config.baseURL else { return }
        var request = URLRequest(url: url)

        // Inject Cloudflare Access headers if configured
        if !config.cfClientId.isEmpty {
            request.setValue(config.cfClientId, forHTTPHeaderField: "CF-Access-Client-Id")
            request.setValue(config.cfClientSecret, forHTTPHeaderField: "CF-Access-Client-Secret")
        }

        webView.load(request)
    }
}
