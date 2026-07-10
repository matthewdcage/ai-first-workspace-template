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
        }
    }
}
