import BackgroundTasks
import Foundation

enum ICloudBackupManager {

    static let backgroundTaskIdentifier = "com.tsubuzaki.DJDX.iCloudBackup"
    static let enabledKey = "ICloudBackup.Enabled"
    static let lastBackupDateKey = "ICloudBackup.LastBackupDate"
    static let restorePromptCompletedKey = "ICloudBackup.RestorePromptCompleted"

    enum BackupError: Error {
        case iCloudUnavailable
        case documentsUnavailable
        case downloadTimedOut
    }

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    // MARK: Background Task

    static func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskIdentifier,
            using: nil
        ) { task in
            scheduleNextBackup()
            guard isEnabled else {
                task.setTaskCompleted(success: true)
                return
            }
            do {
                try backUp()
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
    }

    static func scheduleNextBackup() {
        guard isEnabled else { return }
        let request = BGProcessingTaskRequest(identifier: backgroundTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.earliestBeginDate = Calendar.current.nextDate(
            after: .now,
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime
        )
        try? BGTaskScheduler.shared.submit(request)
    }

    static func cancelScheduledBackup() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundTaskIdentifier)
    }

    // MARK: Backup

    @discardableResult
    static func performBackup() async -> Bool {
        await Task.detached(priority: .userInitiated) {
            do {
                try backUp()
                return true
            } catch {
                return false
            }
        }.value
    }

    static func backUp() throws {
        let fileManager = FileManager.default
        let containerURL = SharedContainer.containerURL
        let backupFolder = try backupFolderURL(in: fileManager)
        try fileManager.createDirectory(at: backupFolder, withIntermediateDirectories: true)

        let stagingURL = fileManager.temporaryDirectory
            .appendingPathComponent("DJDXBackup-\(UUID().uuidString)")
            .appendingPathExtension("zip")
        defer { try? fileManager.removeItem(at: stagingURL) }
        try ZipArchive.zip(directoryAt: containerURL, to: stagingURL)

        let backupDate = Date.now
        let archiveURL = backupFolder.appendingPathComponent("Data.zip")
        if fileManager.fileExists(atPath: archiveURL.path) {
            try fileManager.removeItem(at: archiveURL)
        }
        try fileManager.moveItem(at: stagingURL, to: archiveURL)

        let timestamp = ISO8601DateFormatter().string(from: backupDate)
        try Data(timestamp.utf8).write(
            to: backupFolder.appendingPathComponent("LastBackup"),
            options: .atomic
        )

        UserDefaults.standard.set(backupDate.timeIntervalSince1970, forKey: lastBackupDateKey)
        UserDefaults.standard.set(true, forKey: restorePromptCompletedKey)
    }

    // MARK: Export

    static func exportArchive() async -> URL? {
        await Task.detached(priority: .userInitiated) { () -> URL? in
            do {
                let fileManager = FileManager.default
                let exportDirectory = fileManager.temporaryDirectory
                    .appendingPathComponent("Export-\(UUID().uuidString)", isDirectory: true)
                try fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
                let archiveURL = exportDirectory.appendingPathComponent("DJDX Backup.zip")
                try ZipArchive.zip(directoryAt: SharedContainer.containerURL, to: archiveURL)
                return archiveURL
            } catch {
                return nil
            }
        }.value
    }

    // MARK: Restore

    static func existingBackupDate() async -> Date? {
        await Task.detached(priority: .utility) { () async -> Date? in
            guard let backupFolder = try? backupFolderURL(in: FileManager.default) else {
                return nil
            }
            let timestampURL = backupFolder.appendingPathComponent("LastBackup")
            guard await ensureDownloaded(timestampURL, timeout: 30.0),
                  let timestamp = try? String(contentsOf: timestampURL, encoding: .utf8) else {
                return nil
            }
            return ISO8601DateFormatter().date(
                from: timestamp.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }.value
    }

    static func restore(onProgress: @escaping @Sendable (Int) -> Void) async throws {
        try await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            let backupFolder = try backupFolderURL(in: fileManager)
            let archiveURL = backupFolder.appendingPathComponent("Data.zip")
            onProgress(10)
            guard await ensureDownloaded(archiveURL, timeout: 600.0) else {
                throw BackupError.downloadTimedOut
            }
            onProgress(70)
            let containerURL = SharedContainer.containerURL

            let extractionURL = fileManager.temporaryDirectory
                .appendingPathComponent("DJDXRestore-\(UUID().uuidString)", isDirectory: true)
            defer { try? fileManager.removeItem(at: extractionURL) }
            try ZipArchive.unzip(fileAt: archiveURL, to: extractionURL)
            onProgress(90)

            var restoreRootURL = extractionURL
            let extractedItems = try fileManager.contentsOfDirectory(
                at: extractionURL, includingPropertiesForKeys: [.isDirectoryKey]
            )
            if extractedItems.count == 1,
               extractedItems[0].lastPathComponent == containerURL.lastPathComponent,
               (try? extractedItems[0].resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                restoreRootURL = extractedItems[0]
            }
            for item in try fileManager.contentsOfDirectory(
                at: restoreRootURL, includingPropertiesForKeys: nil
            ) {
                let destinationURL = containerURL.appendingPathComponent(item.lastPathComponent)
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.moveItem(at: item, to: destinationURL)
            }
            // A pre-334 backup has the old flat layout (e.g. Qpro.png at the root, no Images/).
            DataMigration.moveImages(from: containerURL, to: SharedContainer.imagesURL)
            onProgress(100)
        }.value
    }

    // MARK: iCloud

    private static func backupFolderURL(in fileManager: FileManager) throws -> URL {
        guard let containerURL = fileManager.url(forUbiquityContainerIdentifier: nil) else {
            throw BackupError.iCloudUnavailable
        }
        return containerURL
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("Backup", isDirectory: true)
    }

    private static func ensureDownloaded(_ url: URL, timeout: TimeInterval) async -> Bool {
        let fileManager = FileManager.default
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline {
            if isFullyDownloaded(url) { return true }
            try? fileManager.startDownloadingUbiquitousItem(at: url)
            try? await Task.sleep(for: .seconds(1))
        }
        return isFullyDownloaded(url)
    }

    private static func isFullyDownloaded(_ url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        guard let status = try? url.resourceValues(
            forKeys: [.ubiquitousItemDownloadingStatusKey]
        ).ubiquitousItemDownloadingStatus else {
            return true
        }
        return status == .current || status == .downloaded
    }
}
