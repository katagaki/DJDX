import BackgroundTasks
import Foundation

enum SessionOCRBackgroundTask {

    static let identifier = "com.tsubuzaki.DJDX.sessionOCR"

    static func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: identifier,
            using: nil
        ) { task in
            handle(task)
        }
    }

    static func scheduleIfNeeded() {
        guard !IIDXPlaySessionsDatabase.shared.incompletePlays().isEmpty else { return }
        let request = BGProcessingTaskRequest(identifier: identifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGTask) {
        nonisolated(unsafe) let unsafeTask = task
        let work = Task {
            await SessionCaptureProcessor.shared.recover()
            scheduleIfNeeded()
            unsafeTask.setTaskCompleted(success: true)
        }
        task.expirationHandler = {
            work.cancel()
        }
    }
}
