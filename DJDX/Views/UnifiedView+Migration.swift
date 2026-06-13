import SwiftUI
import UIKit

extension UnifiedView {
#if DEBUG
    // Triggered by djdx://max300 to preview the migration fullscreen cover.
    // Animates fake progress over 3 seconds without touching any data.
    func runFakeMigration() async {
        migrationProgress.show(
            title: "Migration.Title",
            message: "Migration.Description"
        )
        let steps = 30
        for step in 1...steps {
            try? await Task.sleep(for: .milliseconds(3000 / steps))
            migrationProgress.updateProgress((step * 100) / steps)
        }
        migrationProgress.hide()
    }
#endif

    func migrateData() async {
        let bemaniWikiMigrationKey = "Internal.BEMANIWikiMigratedToSeparateDB"
        if !UserDefaults.standard.bool(forKey: bemaniWikiMigrationKey) {
            UIApplication.shared.isIdleTimerDisabled = true
            let migrationImporter = IIDXImporter()
            await migrationImporter.migrateBEMANIWikiDataIfNeeded()
            UserDefaults.standard.set(true, forKey: bemaniWikiMigrationKey)
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}
