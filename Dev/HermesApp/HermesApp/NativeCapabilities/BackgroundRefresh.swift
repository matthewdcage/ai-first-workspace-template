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

        task.expirationHandler = { task.setTaskCompleted(success: false) }

        Task {
            let hasNew = await checkForNewActivity()
            if hasNew {
                NotificationManager.shared.schedule(
                    title: "Hermes Update",
                    body: "Your agent has new activity.",
                    delay: 0
                )
            }
            task.setTaskCompleted(success: true)
        }
    }

    private func checkForNewActivity() async -> Bool {
        guard let base = ServerConfig.shared.baseURL else { return false }
        let url = base.appendingPathComponent("/api/hermes/status")
        var request = URLRequest(url: url, timeoutInterval: 20)
        let token = ServerConfig.shared.hermesAuthToken
        if !token.isEmpty { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if !ServerConfig.shared.cfClientId.isEmpty {
            request.setValue(ServerConfig.shared.cfClientId, forHTTPHeaderField: "CF-Access-Client-Id")
            request.setValue(ServerConfig.shared.cfClientSecret, forHTTPHeaderField: "CF-Access-Client-Secret")
        }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hasNew = json["has_new_activity"] as? Bool else { return false }
        return hasNew
    }
}
