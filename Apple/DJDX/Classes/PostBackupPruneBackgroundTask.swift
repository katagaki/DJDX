import BackgroundTasks
import Foundation

enum PostBackupPruneBackgroundTask {

    static let identifier = "com.tsubuzaki.DJDX.postBackupPrune"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            let completion = BackgroundTaskCompletion(task: task)
            let work = Task {
                _ = await ICloudBackupManager.pruneAfterBackup()
                completion.finish(success: !Task.isCancelled)
            }
            task.expirationHandler = {
                work.cancel()
                completion.finish(success: false)
            }
        }
    }

    static func schedule() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
        let request = BGProcessingTaskRequest(identifier: identifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            ICloudBackupManager.logger.error(
                "Failed to schedule post-backup prune: \(error, privacy: .public)"
            )
        }
    }
}
