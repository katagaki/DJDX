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

struct PhaseTimer {

    private let start = ContinuousClock.now
    private var last = ContinuousClock.now
    private var phases: [String] = []

    mutating func mark(_ name: String, bytes: Int64 = 0) {
        let now = ContinuousClock.now
        let seconds = Double((last.duration(to: now)).components.seconds)
            + Double((last.duration(to: now)).components.attoseconds) / 1e18
        last = now
        if bytes > 0 {
            let megabytes = Double(bytes) / 1_048_576.0
            phases.append(String(format: "%@ %.1fs (%.1f MB, %.1f MB/s)",
                                 name, seconds, megabytes, seconds > 0 ? megabytes / seconds : 0))
        } else {
            phases.append(String(format: "%@ %.1fs", name, seconds))
        }
    }

    func summarize() {
        let total = start.duration(to: .now)
        let seconds = Double(total.components.seconds)
            + Double(total.components.attoseconds) / 1e18
        let breakdown = phases.joined(separator: ", ")
        let totalText = String(format: "%.1fs", seconds)
        ICloudBackupManager.logger.log(
            "Backup phases: \(breakdown, privacy: .public) | total \(totalText, privacy: .public)"
        )
    }
}
