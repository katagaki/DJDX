import SwiftUI

extension UnifiedView {
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
