import CoreSpotlight
import SwiftUI
import BackgroundTasks
import UserNotifications

@main
struct HermesAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var serverConfig = ServerConfig.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(serverConfig)
                .onContinueUserActivity(HandoffManager.chatActivityType) { activity in
                    handle(activity)
                }
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    handle(activity)
                }
                .task {
                    PermissionsManager.shared.refreshAll()
                }
        }
    }

    /// Resolves a Handoff continuation or a Spotlight search-result tap
    /// into a URL and loads it in the active WebView.
    private func handle(_ activity: NSUserActivity) {
        let url = HandoffManager.resolve(activity) ?? SpotlightIndexer.deepLink(for: activity)
        guard let url else { return }
        HermesWebViewCoordinator.activeWebView?.load(URLRequest(url: url))
    }
}
