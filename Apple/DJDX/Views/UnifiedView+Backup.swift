import SwiftUI

extension UnifiedView {
    func hasExistingPlayData() async -> Bool {
        if await !IIDXReader().allImportGroups().isEmpty { return true }
        if await SDVXReader().latestImportGroupID() != nil { return true }
        if await PolarisChordReader().latestImportGroupID() != nil { return true }
        return false
    }

    func restoreFromBackup() {
        migrationProgress.show(
            title: "ICloudBackup.Restore.ProgressTitle",
            message: "ICloudBackup.Restore.ProgressMessage"
        )
        Task {
            do {
                try await ICloudBackupManager.restore { [migrationProgress] percentage in
                    Task { @MainActor in
                        migrationProgress.updateProgress(percentage)
                    }
                }
                hasCompletedRestorePrompt = true
                NotificationCenter.default.post(name: .dataImported, object: nil)
                NotificationCenter.default.post(name: .externalDataChanged, object: nil)
                migrationProgress.hide()
                try? await Task.sleep(for: .seconds(0.75))
                isBackupRestoreCompleted = true
            } catch {
                migrationProgress.hide()
                try? await Task.sleep(for: .seconds(0.75))
                isBackupRestoreFailed = true
            }
        }
    }
}
