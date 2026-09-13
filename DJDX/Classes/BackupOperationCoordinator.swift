import BackgroundTasks
import Foundation

actor BackupOperationCoordinator {

    func backUp() async throws {
        try await ICloudBackupManager.createBackup()
    }

    func exportArchive() async throws -> URL {
        try await ICloudBackupManager.createExportArchive()
    }

    func pruneStorage() async -> StorageReport {
        await StoragePruner.prune()
    }
}

final class BackgroundTaskCompletion: @unchecked Sendable {

    private let lock = NSLock()
    private let task: BGTask
    private var isFinished = false

    init(task: BGTask) {
        self.task = task
    }

    func finish(success: Bool) {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        isFinished = true
        lock.unlock()
        task.setTaskCompleted(success: success)
    }
}
