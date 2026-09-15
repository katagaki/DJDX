import BackgroundTasks
import Foundation
import os

enum ICloudBackupManager {

    static let logger = Logger(subsystem: "com.tsubuzaki.DJDX", category: "iCloudBackup")

    static let backgroundTaskIdentifier = "com.tsubuzaki.DJDX.iCloudBackup"
    static let enabledKey = "ICloudBackup.Enabled"
    static let lastBackupDateKey = "ICloudBackup.LastBackupDate"
    static let restorePromptCompletedKey = "ICloudBackup.RestorePromptCompleted"

    static let defaultsSnapshotName = "StandardDefaults.plist"
    static let dataArchiveName = "Data.zip"
    static let imagesArchiveName = "Images.zip"
    static let imagesManifestKey = "ICloudBackup.ImagesManifest"

    static var sessionImagesURL: URL {
        SharedContainer.containerURL
            .appendingPathComponent("Sessions", isDirectory: true)
            .appendingPathComponent("Images", isDirectory: true)
    }

    private static let operationCoordinator = BackupOperationCoordinator()

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
            let completion = BackgroundTaskCompletion(task: task)
            let backupTask = Task {
                do {
                    try await backUp()
                    completion.finish(success: true)
                } catch {
                    logger.error("Scheduled backup failed: \(error, privacy: .public)")
                    completion.finish(success: false)
                }
            }
            task.expirationHandler = {
                backupTask.cancel()
                completion.finish(success: false)
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
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logger.error("Failed to schedule backup: \(error, privacy: .public)")
        }
    }

    static func cancelScheduledBackup() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundTaskIdentifier)
    }

    // MARK: Backup

    @discardableResult
    static func performBackup() async -> String? {
        await Task.detached(priority: .userInitiated) { () -> String? in
            do {
                try await backUp()
                return nil
            } catch {
                logger.error("Manual backup failed: \(error, privacy: .public)")
                return failureDetail(for: error)
            }
        }.value
    }

    static func fileSize(of url: URL) -> Int64 {
        let values = try? url.resourceValues(
            forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        )
        return Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
    }

    static func failureDetail(for error: Error) -> String {
        switch error {
        case BackupError.iCloudUnavailable:
            return "Signed out of iCloud, iCloud Drive off, or DJDX disabled under iCloud settings."
        case BackupError.documentsUnavailable:
            return "iCloud Documents container could not be opened."
        case BackupError.downloadTimedOut:
            return "Backup did not finish downloading from iCloud."
        default:
            let nsError = error as NSError
            return "\(nsError.domain) \(nsError.code): \(nsError.localizedDescription)"
        }
    }

    static func backUp() async throws {
        defer { PostBackupPruneBackgroundTask.schedule() }
        try await operationCoordinator.backUp()
    }

    static func pruneAfterBackup() async -> StorageReport {
        await operationCoordinator.pruneStorage()
    }

    static func createBackup() async throws {
        let fileManager = FileManager.default
        removeStaleWorkingFiles(using: fileManager)
        let containerURL = SharedContainer.containerURL
        let backupFolder = try backupFolderURL(in: fileManager)
        try fileManager.createDirectory(at: backupFolder, withIntermediateDirectories: true)

        writeDefaultsSnapshot(to: containerURL)

        var phase = PhaseTimer()
        let stagingDirectory = try await stagedCopy(
            of: containerURL,
            using: fileManager,
            excludingSessionImages: true
        )
        defer { try? fileManager.removeItem(at: stagingDirectory) }
        phase.mark("stage")

        let stagingURL = fileManager.temporaryDirectory
            .appendingPathComponent("DJDXBackup-\(UUID().uuidString)")
            .appendingPathExtension("zip")
        defer { try? fileManager.removeItem(at: stagingURL) }
        try Task.checkCancellation()
        try ZipArchive.zip(directoryAt: stagingDirectory, to: stagingURL)
        try? fileManager.removeItem(at: stagingDirectory)
        phase.mark("zip", bytes: fileSize(of: stagingURL))
        try Task.checkCancellation()

        let backupDate = Date.now
        let archiveURL = backupFolder.appendingPathComponent(dataArchiveName)
        if fileManager.fileExists(atPath: archiveURL.path) {
            try fileManager.removeItem(at: archiveURL)
        }
        try fileManager.moveItem(at: stagingURL, to: archiveURL)
        phase.mark("handoff")

        let rebuiltImages = try updateImagesArchive(in: backupFolder, using: fileManager)
        phase.mark(rebuiltImages ? "images" : "images (unchanged)")
        phase.summarize()

        let timestampURL = backupFolder.appendingPathComponent("LastBackup")
        let timestamp = ISO8601DateFormatter().string(from: backupDate)
        try Data(timestamp.utf8).write(to: timestampURL, options: .atomic)

        UserDefaults.standard.set(backupDate.timeIntervalSince1970, forKey: lastBackupDateKey)
        UserDefaults.standard.set(true, forKey: restorePromptCompletedKey)
    }

    // MARK: Export

    static func exportArchive() async -> URL? {
        await Task.detached(priority: .userInitiated) { () -> URL? in
            do {
                return try await operationCoordinator.exportArchive()
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
            let archiveURL = backupFolder.appendingPathComponent(dataArchiveName)
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

            let restoreRootURL = try unwrappedRoot(of: extractionURL, using: fileManager)
            for item in try fileManager.contentsOfDirectory(
                at: restoreRootURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
            ) {
                let destinationURL = containerURL.appendingPathComponent(item.lastPathComponent)
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.moveItem(at: item, to: destinationURL)
            }
            try await restoreImagesArchive(
                from: backupFolder, to: containerURL, using: fileManager
            )
            applyDefaultsSnapshot(from: containerURL)
            // A pre-334 backup has the old flat layout (e.g. Qpro.png at the root, no Images/).
            DataMigration.moveImages(from: containerURL, to: SharedContainer.imagesURL)
            onProgress(100)
        }.value
    }

}

extension ICloudBackupManager {

    // MARK: Staging

    static func createExportArchive() async throws -> URL {
        let fileManager = FileManager.default
        removeStaleWorkingFiles(using: fileManager)
        let exportDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("Export-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        let archiveURL = exportDirectory.appendingPathComponent("DJDX Backup.zip")
        writeDefaultsSnapshot(to: SharedContainer.containerURL)
        let stagingDirectory = try await stagedCopy(
            of: SharedContainer.containerURL,
            using: fileManager,
            excludingSessionImages: false
        )
        defer { try? fileManager.removeItem(at: stagingDirectory) }
        try ZipArchive.zip(directoryAt: stagingDirectory, to: archiveURL)
        try Task.checkCancellation()
        return archiveURL
    }

    static let workingFilePrefixes = ["Export-", "DJDXStaging-", "DJDXBackup-", "DJDXRestore-"]

    static func removeStaleWorkingFiles(using fileManager: FileManager) {
        guard let items = try? fileManager.contentsOfDirectory(
            at: fileManager.temporaryDirectory, includingPropertiesForKeys: nil
        ) else { return }
        for item in items {
            let name = item.lastPathComponent
            guard workingFilePrefixes.contains(where: { name.hasPrefix($0) }) else { continue }
            try? fileManager.removeItem(at: item)
        }
    }

    private static func stagedCopy(
        of containerURL: URL,
        using fileManager: FileManager,
        excludingSessionImages: Bool
    ) async throws -> URL {
        let stagingURL = fileManager.temporaryDirectory
            .appendingPathComponent("DJDXStaging-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: true)
        do {
            try await copyBackupItems(
                from: containerURL,
                to: stagingURL,
                rootURL: containerURL,
                using: fileManager,
                excludingSessionImages: excludingSessionImages
            )
            return stagingURL
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            throw error
        }
    }

    private static func copyBackupItems(
        from sourceURL: URL,
        to destinationURL: URL,
        rootURL: URL,
        using fileManager: FileManager,
        excludingSessionImages: Bool
    ) async throws {
        let items = try fileManager.contentsOfDirectory(
            at: sourceURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        for item in items {
            try Task.checkCancellation()
            guard shouldIncludeInBackup(
                item, rootURL: rootURL, excludingSessionImages: excludingSessionImages
            ) else { continue }

            let destination = destinationURL.appendingPathComponent(item.lastPathComponent)
            let isDirectory = try item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
            if isDirectory {
                try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
                try await copyBackupItems(
                    from: item,
                    to: destination,
                    rootURL: rootURL,
                    using: fileManager,
                    excludingSessionImages: excludingSessionImages
                )
            } else {
                do {
                    try fileManager.linkItem(at: item, to: destination)
                } catch {
                    try fileManager.copyItem(at: item, to: destination)
                }
            }
        }
    }

    private static func shouldIncludeInBackup(
        _ url: URL,
        rootURL: URL,
        excludingSessionImages: Bool
    ) -> Bool {
        if excludingSessionImages,
           url.standardizedFileURL == sessionImagesURL.standardizedFileURL {
            return false
        }
        guard url.deletingLastPathComponent().standardizedFileURL == rootURL.standardizedFileURL else {
            return true
        }
        let name = url.lastPathComponent
        // External-data databases can be downloaded again. WidgetData is derived from user data.
        return !name.hasPrefix("ExD_") && name != "WidgetData"
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

    static func ensureDownloaded(_ url: URL, timeout: TimeInterval) async -> Bool {
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
