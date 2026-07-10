import BackgroundTasks
import Foundation

/// Polls Hermes for new agent activity while the app is in the background
/// and delivers a local notification if anything changed.
final class BackgroundRefresh {
    static let shared = BackgroundRefresh()
    static let taskIdentifier = "com.hermesapp.refresh"

    private init() {}

    func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 min minimum
        try? BGTaskScheduler.shared.submit(request)
    }

    func handleRefresh(task: BGAppRefreshTask) {
        schedule() // re-arm for next cycle

        let refreshTask = Task {
            let hasNew = await checkForNewActivity()
            if hasNew {
                NotificationManager.shared.schedule(
                    title: String(localized: "notification.agent_update.title"),
                    body: String(localized: "notification.agent_update.body"),
                    delay: 0
                )
            }
            task.setTaskCompleted(success: true)
        }

        // Cancel outstanding work when the system revokes our time budget,
        // otherwise the app can be penalized for overrunning background limits.
        task.expirationHandler = {
            refreshTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }

    private func checkForNewActivity() async -> Bool {
        guard let request = await ServerConfig.shared.authenticatedRequest(
            path: "api/hermes/status",
            timeoutInterval: 20
        ) else { return false }

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hasNew = json["has_new_activity"] as? Bool else { return false }
        return hasNew
    }
}
