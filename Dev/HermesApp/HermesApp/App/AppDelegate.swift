import UIKit
import BackgroundTasks
import UserNotifications
import WebKit

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationCategories.registerAll()

        let didRegisterBackgroundRefresh = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundRefresh.taskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            BackgroundRefresh.shared.handleRefresh(task: refreshTask)
        }
        if !didRegisterBackgroundRefresh {
            print("[HermesApp] Failed to register background refresh task.")
        }

        SpotlightIndexer.reindexAll()

        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        BackgroundRefresh.shared.schedule()
        SpotlightIndexer.reindexAll()
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        Task { @MainActor in
            SpotlightIndexer.handle(userActivity: userActivity, webView: HermesWebViewCoordinator.activeWebView)
        }
        return true
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // Route reply/open actions on rich agent-update notifications
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let sessionId = response.notification.request.content.userInfo["sessionId"] as? String
        NotificationCategories.handle(
            response: response,
            sessionId: sessionId,
            webView: HermesWebViewCoordinator.activeWebView
        )
        completionHandler()
    }
}
