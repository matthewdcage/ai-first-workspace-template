import SwiftUI
import UIKit
import WebKit

// MARK: - Injected scripts

/// Force-sets the viewport meta before the page's own tag is parsed.
private let mobileViewportJS = """
(function() {
    var existing = document.querySelector('meta[name="viewport"]');
    if (existing) { existing.remove(); }
    var meta = document.createElement('meta');
    meta.name = 'viewport';
    meta.content = 'width=device-width, initial-scale=1, viewport-fit=cover, user-scalable=yes';
    var head = document.head || document.documentElement;
    head.insertBefore(meta, head.firstChild);
})();
"""

/// Injects a <style> at document start to improve mobile readability of the desktop-first Hermes UI.
private let mobileCSSJS = """
(function() {
    var style = document.createElement('style');
    style.textContent = `
        /* Remove hard min-width constraints that force horizontal scroll */
        body, #__next, main, [class*="container"], [class*="layout"] {
            min-width: unset !important;
            max-width: 100vw !important;
            overflow-x: hidden !important;
        }
        /* Improve base readability */
        html { font-size: 16px !important; }
        /* Terminal / chat areas: keep full height but cap width */
        [class*="terminal"], [class*="chat"], [class*="messages"] {
            max-width: 100vw !important;
            overflow-x: hidden !important;
        }
        /* Increase tap target sizes */
        button, a, [role="button"] {
            min-height: 44px !important;
            min-width: 44px !important;
        }
        input, textarea, select {
            font-size: 16px !important;
        }
        /* Prevent text from overflowing */
        pre, code {
            white-space: pre-wrap !important;
            word-break: break-all !important;
        }
        /* Make sidebar / nav drawers scrollable on mobile */
        nav, aside,
        [class*="sidebar"], [class*="Sidebar"],
        [class*="nav-menu"], [class*="NavMenu"],
        [class*="drawer"], [class*="Drawer"],
        [class*="side-panel"], [class*="SidePanel"],
        [class*="menu-panel"], [class*="MenuPanel"] {
            overflow-y: auto !important;
            -webkit-overflow-scrolling: touch !important;
            overscroll-behavior: contain !important;
            max-height: 100dvh !important;
        }
    `;
    var head = document.head || document.documentElement;
    head.insertBefore(style, head.firstChild);
})();
"""

/// Rewrites WebSocket and EventSource URLs that hard-code localhost/127.0.0.1 to use
/// the page's actual origin.  Hermes's Next.js frontend may have `ws://localhost:9119`
/// baked in at build time; when loaded through a Cloudflare tunnel from an iOS device
/// `localhost` resolves to the device itself (nothing listening) → immediate 1006 close.
private let wsReconnectJS = """
(function() {
    function fixURL(url) {
        try {
            var u = new URL(url, window.location.href);
            if (u.hostname === 'localhost' || u.hostname === '127.0.0.1') {
                var origin = window.location.origin;
                var wsScheme = origin.startsWith('https') ? 'wss' : 'ws';
                var httpScheme = origin.startsWith('https') ? 'https' : 'http';
                if (u.protocol === 'ws:' || u.protocol === 'wss:') {
                    u.protocol = wsScheme;
                } else {
                    u.protocol = httpScheme;
                }
                u.hostname = window.location.hostname;
                u.port = window.location.port;
                return u.toString();
            }
        } catch(e) {}
        return url;
    }

    // Patch WebSocket
    var _WS = window.WebSocket;
    function PatchedWebSocket(url, protocols) {
        var fixed = fixURL(url);
        var ws = (protocols !== undefined) ? new _WS(fixed, protocols) : new _WS(fixed);
        return ws;
    }
    PatchedWebSocket.prototype = _WS.prototype;
    PatchedWebSocket.CONNECTING = _WS.CONNECTING;
    PatchedWebSocket.OPEN       = _WS.OPEN;
    PatchedWebSocket.CLOSING    = _WS.CLOSING;
    PatchedWebSocket.CLOSED     = _WS.CLOSED;
    window.WebSocket = PatchedWebSocket;

    // Patch EventSource (SSE events feed)
    if (window.EventSource) {
        var _ES = window.EventSource;
        window.EventSource = function(url, init) {
            var fixed = fixURL(url);
            return (init !== undefined) ? new _ES(fixed, init) : new _ES(fixed);
        };
        window.EventSource.prototype = _ES.prototype;
    }
})();
"""

// MARK: - WebView (legacy, kept for compatibility)

struct WebView: UIViewRepresentable {
    @EnvironmentObject var config: ServerConfig

    func makeCoordinator() -> HermesWebViewCoordinator {
        HermesWebViewCoordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let wkConfig = WKWebViewConfiguration()
        wkConfig.allowsInlineMediaPlayback = true
        wkConfig.mediaTypesRequiringUserActionForPlayback = []
        wkConfig.applicationNameForUserAgent = "HermesApp"

        let bridge = NativeBridge(coordinator: context.coordinator)
        for name in NativeBridge.handlerNames {
            wkConfig.userContentController.add(bridge, name: name)
        }
        wkConfig.userContentController.addUserScript(WKUserScript(
            source: NativeBridge.injectedJavaScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))
        addMobileScripts(to: wkConfig.userContentController)

        let webView = WKWebView(frame: .zero, configuration: wkConfig)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.scrollView.keyboardDismissMode = .interactive

        context.coordinator.webView = webView
        context.coordinator.config = config
        SpeechBridge.shared.webView = webView
        load(webView: webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    private func load(webView: WKWebView) {
        guard let url = config.baseURL else { return }
        var request = URLRequest(url: url)
        config.applyAuthentication(to: &request)
        webView.load(request)
    }
}

// MARK: - Container with loading + error states

struct WebViewContainer: View {
    @EnvironmentObject var config: ServerConfig
    @StateObject private var state = WebViewState()
    @State private var reloadTrigger = UUID()
    @State private var activeSheet: HermesSheet?

    var body: some View {
        ZStack {
            WebViewInternal(state: state)
                .id(reloadTrigger)
                .environmentObject(config)

            if state.isLoading && state.errorMessage == nil {
                HermesLoadingOverlay(progress: state.estimatedProgress)
                    .transition(.opacity)
            }

            if let error = state.errorMessage {
                HermesErrorOverlay(error: error) {
                    retry()
                } changeServer: {
                    activeSheet = .settings
                }
                .transition(.opacity)
            }
        }
        .animation(.snappy, value: state.isLoading)
        .animation(.snappy, value: state.errorMessage)
        .background(Color(.systemBackground))
        .safeAreaInset(edge: .top, spacing: 0) {
            HermesConnectionBar(
                state: state,
                host: config.baseURL?.host ?? "Hermes",
                favorites: config.favoriteConnections,
                currentURL: config.serverURL,
                onSelectFavorite: switchToFavorite,
                onReload: reload,
                onMenu: { activeSheet = .menu }
            )
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HermesCommandBar(
                canGoBack: state.canGoBack,
                canGoForward: state.canGoForward,
                isLoading: state.isLoading,
                onBack: { HermesWebViewCoordinator.activeWebView?.goBack() },
                onForward: { HermesWebViewCoordinator.activeWebView?.goForward() },
                onReload: reload,
                onShare: shareCurrentPage,
                onSettings: { activeSheet = .settings }
            )
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .menu:
                HermesMainMenuSheet(
                    state: state,
                    host: config.baseURL?.host ?? "Hermes",
                    favorites: config.favoriteConnections,
                    currentURL: config.serverURL,
                    lastSuccessfulConnection: config.lastSuccessfulConnection,
                    connectionLog: Array(config.connectionLog.prefix(6)),
                    onClose: { activeSheet = nil },
                    onReload: reload,
                    onShare: shareCurrentPage,
                    onSettings: { activeSheet = .settings },
                    onCapabilities: { activeSheet = .capabilities },
                    onSelectFavorite: { favorite in
                        activeSheet = nil
                        switchToFavorite(favorite)
                    },
                    onDisconnect: {
                        activeSheet = nil
                        config.disconnect()
                    }
                )
                .presentationDetents([.medium, .large])
            case .settings:
                SetupView {
                    activeSheet = nil
                    openConfiguredServer()
                }
                    .environmentObject(config)
                    .presentationDetents([.large])
            case .capabilities:
                NativeCapabilitiesSheet()
                    .presentationDetents([.medium])
            }
        }
    }

    private func reload() {
        if state.isLoading, let webView = HermesWebViewCoordinator.activeWebView {
            webView.stopLoading()
            state.finishLoading()
            return
        }

        let hadError = state.errorMessage != nil
        state.prepareForReload()

        if hadError {
            reloadTrigger = UUID()
        } else if let webView = HermesWebViewCoordinator.activeWebView {
            webView.reload()
        } else {
            reloadTrigger = UUID()
        }
    }

    private func openConfiguredServer() {
        HermesWebViewCoordinator.activeWebView?.stopLoading()
        state.prepareForReload()
        reloadTrigger = UUID()
    }

    private func switchToFavorite(_ favorite: FavoriteConnection) {
        config.selectFavorite(favorite)
        config.save()
        openConfiguredServer()
    }

    private func retry() {
        state.prepareForReload()
        reloadTrigger = UUID()
    }

    private func shareCurrentPage() {
        guard let item = state.currentURL ?? config.baseURL else { return }
        guard let topVC = HermesWebViewCoordinator.topViewController() else { return }

        let activity = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        topVC.present(activity, animated: true)
    }
}

private enum HermesSheet: String, Identifiable {
    case menu
    case settings
    case capabilities

    var id: String { rawValue }
}

@MainActor
final class WebViewState: ObservableObject {
    @Published var isLoading = true
    @Published var estimatedProgress = 0.05
    @Published var errorMessage: String?
    @Published var pageTitle = "Hermes"
    @Published var currentURL: URL?
    @Published var canGoBack = false
    @Published var canGoForward = false
    private var hasRecordedConnectionSuccess = false

    var statusText: String {
        if let errorMessage, !errorMessage.isEmpty {
            return "Needs attention"
        }
        if isLoading {
            return "Connecting"
        }
        return isSecure ? "Secure connection" : "Connected"
    }

    var isSecure: Bool {
        currentURL?.scheme?.lowercased() == "https"
    }

    func apply(_ snapshot: WebViewSnapshot) {
        pageTitle = snapshot.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Hermes"
        currentURL = snapshot.url
        isLoading = snapshot.isLoading
        estimatedProgress = max(0.05, min(snapshot.estimatedProgress, 1))
        canGoBack = snapshot.canGoBack
        canGoForward = snapshot.canGoForward
    }

    func prepareForReload() {
        errorMessage = nil
        isLoading = true
        estimatedProgress = 0.05
        hasRecordedConnectionSuccess = false
    }

    func finishLoading() {
        isLoading = false
        estimatedProgress = 1
        errorMessage = nil
    }

    func fail(with message: String) {
        isLoading = false
        errorMessage = message
    }

    func shouldRecordConnectionSuccess() -> Bool {
        guard !hasRecordedConnectionSuccess else { return false }
        hasRecordedConnectionSuccess = true
        return true
    }
}

private struct HermesConnectionBar: View {
    @ObservedObject var state: WebViewState
    let host: String
    let favorites: [FavoriteConnection]
    let currentURL: String
    let onSelectFavorite: (FavoriteConnection) -> Void
    let onReload: () -> Void
    let onMenu: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.16))
                    Image(systemName: statusImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(statusColor)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 1) {
                    Text(state.pageTitle)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text("\(state.statusText) • \(host)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if favorites.count > 1 {
                    Menu {
                        ForEach(favorites) { favorite in
                            Button {
                                onSelectFavorite(favorite)
                            } label: {
                                Label(
                                    favorite.displayName,
                                    systemImage: favorite.serverURL == currentURL ? "checkmark.circle.fill" : "star"
                                )
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Switch favorite connection")
                }

                Button(action: onReload) {
                    Image(systemName: state.isLoading ? "xmark" : "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(state.isLoading ? "Stop loading" : "Reload")

                Button(action: onMenu) {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Main menu")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)

            ProgressView(value: state.isLoading ? state.estimatedProgress : 1)
                .progressViewStyle(.linear)
                .tint(statusColor)
                .opacity(state.isLoading ? 1 : 0)
                .frame(height: 2)
        }
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var statusColor: Color {
        if state.errorMessage != nil { return .red }
        if state.isLoading { return .blue }
        return state.isSecure ? .green : .orange
    }

    private var statusImage: String {
        if state.errorMessage != nil { return "exclamationmark.triangle.fill" }
        if state.isLoading { return "bolt.horizontal.circle.fill" }
        return state.isSecure ? "lock.fill" : "network"
    }
}

private struct HermesCommandBar: View {
    let canGoBack: Bool
    let canGoForward: Bool
    let isLoading: Bool
    let onBack: () -> Void
    let onForward: () -> Void
    let onReload: () -> Void
    let onShare: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            chromeButton("chevron.left", label: "Back", disabled: !canGoBack, action: onBack)
            chromeButton("chevron.right", label: "Forward", disabled: !canGoForward, action: onForward)

            Spacer(minLength: 8)

            chromeButton(isLoading ? "xmark" : "arrow.clockwise", label: isLoading ? "Stop loading" : "Reload", action: onReload)
            chromeButton("square.and.arrow.up", label: "Share", action: onShare)
            chromeButton("slider.horizontal.3", label: "Settings", action: onSettings)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func chromeButton(
        _ systemImage: String,
        label: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 42, height: 36)
        }
        .buttonStyle(.plain)
        .foregroundStyle(disabled ? .tertiary : .primary)
        .disabled(disabled)
        .accessibilityLabel(label)
    }
}

private struct HermesLoadingOverlay: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(.blue.opacity(0.12), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: max(0.08, progress))
                    .stroke(.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "sparkles")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.blue)
            }
            .frame(width: 70, height: 70)

            VStack(spacing: 4) {
                Text("Opening Hermes")
                    .font(.headline)
                Text("Preparing the secure native session")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .ignoresSafeArea()
        .accessibilityElement(children: .combine)
    }
}

private struct HermesErrorOverlay: View {
    let error: String
    let retry: () -> Void
    let changeServer: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(.red)

            VStack(spacing: 6) {
                Text("Hermes is unavailable")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }

            HStack(spacing: 12) {
                Button(action: retry) {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: changeServer) {
                    Label("Settings", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: 360)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .ignoresSafeArea()
    }
}

private struct HermesMainMenuSheet: View {
    @ObservedObject var state: WebViewState
    let host: String
    let favorites: [FavoriteConnection]
    let currentURL: String
    let lastSuccessfulConnection: ConnectionLogEntry?
    let connectionLog: [ConnectionLogEntry]
    let onClose: () -> Void
    let onReload: () -> Void
    let onShare: () -> Void
    let onSettings: () -> Void
    let onCapabilities: () -> Void
    let onSelectFavorite: (FavoriteConnection) -> Void
    let onDisconnect: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: state.isSecure ? "lock.fill" : "network")
                            .font(.headline)
                            .foregroundStyle(state.isSecure ? .green : .orange)
                            .frame(width: 34, height: 34)
                            .background((state.isSecure ? Color.green : Color.orange).opacity(0.12), in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(state.pageTitle)
                                .font(.headline)
                                .lineLimit(1)
                            Text(host)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if favorites.count > 1 {
                    Section("Switch Connection") {
                        ForEach(favorites) { favorite in
                            Button {
                                onSelectFavorite(favorite)
                            } label: {
                                Label(
                                    favorite.displayName,
                                    systemImage: favorite.serverURL == currentURL ? "checkmark.circle.fill" : "star"
                                )
                            }
                        }
                    }
                }

                if lastSuccessfulConnection != nil || !connectionLog.isEmpty {
                    Section("Last Successful") {
                        if let lastSuccessfulConnection {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lastSuccessfulConnection.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(lastSuccessfulConnection.serverURL)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Text(lastSuccessfulConnection.occurredAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    Section("Recent Sessions") {
                        ForEach(connectionLog.filter { $0.kind == .session }.prefix(4)) { entry in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.title)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                Text(entry.detail ?? entry.serverURL)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        onClose()
                        onReload()
                    } label: {
                        Label("Reload Hermes", systemImage: "arrow.clockwise")
                    }

                    Button {
                        onClose()
                        onShare()
                    } label: {
                        Label("Share Current Page", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        onCapabilities()
                    } label: {
                        Label("Native Capabilities", systemImage: "iphone.gen3.radiowaves.left.and.right")
                    }
                }

                Section {
                    Button {
                        onSettings()
                    } label: {
                        Label("Connection Settings", systemImage: "slider.horizontal.3")
                    }

                    Button(role: .destructive) {
                        onDisconnect()
                    } label: {
                        Label("Change Server", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Hermes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onClose)
                }
            }
        }
    }
}

private struct NativeCapabilitiesSheet: View {
    @StateObject private var permissions = PermissionsManager.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NativeCapabilityRow(title: "Voice Input", systemImage: "waveform", status: permissions.speechRecognition)
                    NativeCapabilityRow(title: "Microphone", systemImage: "mic", status: permissions.microphone)
                    NativeCapabilityRow(title: "Notifications", systemImage: "bell", status: permissions.notifications)
                    NativeCapabilityRow(title: "Files and Photos", systemImage: "photo.on.rectangle", status: permissions.photoLibrary)
                }

                Section {
                    Button {
                        Task {
                            await permissions.requestAll()
                        }
                    } label: {
                        Label("Review Permissions", systemImage: "checkmark.shield")
                    }
                }
            }
            .navigationTitle("Native Capabilities")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                permissions.refreshAll()
            }
        }
    }
}

private struct NativeCapabilityRow: View {
    let title: String
    let systemImage: String
    let status: PermissionsManager.Status

    var body: some View {
        Label {
            HStack {
                Text(title)
                Spacer()
                Text(status.displayTitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(status.displayColor)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
        }
    }
}

private extension PermissionsManager.Status {
    var displayTitle: String {
        switch self {
        case .notDetermined:
            return "Not Set"
        case .granted:
            return "Allowed"
        case .denied:
            return "Denied"
        }
    }

    var displayColor: Color {
        switch self {
        case .notDetermined:
            return .secondary
        case .granted:
            return .green
        case .denied:
            return .red
        }
    }
}

// MARK: - Internal WKWebView wrapper that reports load state

private struct WebViewInternal: UIViewRepresentable {
    @EnvironmentObject var config: ServerConfig
    @ObservedObject var state: WebViewState

    func makeCoordinator() -> HermesWebViewCoordinator {
        HermesWebViewCoordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let wkConfig = WKWebViewConfiguration()
        wkConfig.allowsInlineMediaPlayback = true
        wkConfig.mediaTypesRequiringUserActionForPlayback = []
        wkConfig.applicationNameForUserAgent = "HermesApp"

        let bridge = NativeBridge(coordinator: context.coordinator)
        for name in NativeBridge.handlerNames {
            wkConfig.userContentController.add(bridge, name: name)
        }
        wkConfig.userContentController.addUserScript(WKUserScript(
            source: NativeBridge.injectedJavaScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))
        addMobileScripts(to: wkConfig.userContentController)

        let webView = WKWebView(frame: .zero, configuration: wkConfig)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.scrollView.keyboardDismissMode = .interactive
        webView.isOpaque = false
        webView.backgroundColor = .clear

        context.coordinator.webView = webView
        context.coordinator.config = config
        SpeechBridge.shared.webView = webView
        context.coordinator.onStateChanged = { snapshot in
            state.apply(snapshot)
        }
        context.coordinator.onLoadStarted = {
            state.prepareForReload()
        }
        context.coordinator.onLoadFinished = {
            state.finishLoading()
            if state.shouldRecordConnectionSuccess() {
                config.recordConnectionSuccess(title: webView.title)
            }
            config.recordSession(title: webView.title, url: webView.url)
        }
        context.coordinator.onLoadFailed = { error in
            state.fail(with: error)
        }
        context.coordinator.observe(webView: webView)

        guard let url = config.baseURL else { return webView }

        // Seed auth token before the page's own JS runs so WebSocket/SSE connections
        // that open during Next.js hydration are already authenticated.
        let token = config.hermesAuthToken
        if !token.isEmpty {
            wkConfig.userContentController.addUserScript(WKUserScript(
                source: CFAuthInjector.earlyTokenScript(token: token),
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            ))
        }

        var request = URLRequest(url: url, timeoutInterval: 15)
        config.applyAuthentication(to: &request)

        if !token.isEmpty {
            CFAuthInjector.preSeedCookie(token: token, for: url, in: wkConfig.websiteDataStore) {
                webView.load(request)
            }
        } else {
            webView.load(request)
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// MARK: - Shared script injection

@MainActor
private func addMobileScripts(to controller: WKUserContentController) {
    for (source, time) in [
        (wsReconnectJS,    WKUserScriptInjectionTime.atDocumentStart),
        (mobileViewportJS, WKUserScriptInjectionTime.atDocumentStart),
        (mobileCSSJS,      WKUserScriptInjectionTime.atDocumentStart),
    ] {
        controller.addUserScript(WKUserScript(
            source: source,
            injectionTime: time,
            forMainFrameOnly: true
        ))
    }
}
