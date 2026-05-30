//
//  UnifiedView+Migration.swift
//  DJDX
//
//  Created by Claude on 2026/05/29.
//

import SwiftData
import SwiftUI
import UIKit

extension UnifiedView {
    func migrateData() async {
        let defaults = UserDefaults.standard
        let dataMigrationKeys = [
            "Internal.DataMigrationForEpolisToPinkyCrush.2",
            "Internal.DataMigrationForSwiftDataToSQLite",
            "Internal.BEMANIWikiMigratedToSeparateDB"
        ]

        UIApplication.shared.isIdleTimerDisabled = true
        for dataMigrationKey in dataMigrationKeys where !defaults.bool(forKey: dataMigrationKey) {
            switch dataMigrationKey {
            case "Internal.DataMigrationForEpolisToPinkyCrush.2":
                debugPrint("Performing migration when migrating from 1.x to 32.x")
                progressAlertManager.show(
                    title: "Migration.Title",
                    message: "Migration.Description"
                ) {
                    let importGroups = try? modelContext.fetch(FetchDescriptor<ImportGroup>())
                    for importGroup in importGroups ?? [] where importGroup.iidxVersion == nil {
                        importGroup.iidxVersion = .epolis
                    }
                    progressAlertManager.hide()
                }
            case "Internal.DataMigrationForSwiftDataToSQLite":
                await migrateSwiftDataToSQLite()
            case "Internal.BEMANIWikiMigratedToSeparateDB":
                let migrationImporter = DataImporter()
                await migrationImporter.migrateBEMANIWikiDataIfNeeded()
            default: break
            }
            UserDefaults.standard.set(true, forKey: dataMigrationKey)
        }
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func migrateSwiftDataToSQLite() async {
        debugPrint("Performing migration from SwiftData to SQLite")

        // Fetch all SwiftData ImportGroups
        let importGroups: [ImportGroup] = (try? modelContext.fetch(
            FetchDescriptor<ImportGroup>(
                sortBy: [SortDescriptor(\.importDate, order: .forward)]
            )
        )) ?? []

        // If no data, skip migration
        guard !importGroups.isEmpty else {
            debugPrint("No SwiftData data to migrate")
            UserDefaults.standard.set(true, forKey: "Internal.DataMigrationDeleteOldSQLiteData")
            return
        }

        // Fetch songs and tower entries
        let songs: [IIDXSong] = (try? modelContext.fetch(
            FetchDescriptor<IIDXSong>()
        )) ?? []
        let towerEntries: [IIDXTowerEntry] = (try? modelContext.fetch(
            FetchDescriptor<IIDXTowerEntry>()
        )) ?? []

        let totalGroups = importGroups.count

        await MainActor.run {
            progressAlertManager.show(
                title: "Migration.Title",
                message: "Migration.Description"
            )
        }

        // Small delay to allow the alert to appear
        try? await Task.sleep(for: .milliseconds(500))

        let importer = DataImporter()

        // Migrate ImportGroups and their song records
        for (index, importGroup) in importGroups.enumerated() {
            await importer.migrateImportGroup(
                importGroup,
                songRecords: importGroup.iidxData ?? []
            )

            let progress = ((index + 1) * 100) / totalGroups
            await MainActor.run {
                progressAlertManager.updateProgress(progress)
            }
        }

        // Migrate IIDXSong data
        await importer.migrateSongs(songs)

        // Migrate IIDXTowerEntry data
        await importer.migrateTowerEntries(towerEntries)

        // Delete all SwiftData entries after successful migration
        #if DEBUG
        debugPrint("Deleting SwiftData entries after migration")
        try? modelContext.delete(model: IIDXSongRecord.self)
        try? modelContext.delete(model: ImportGroup.self)
        try? modelContext.delete(model: IIDXSong.self)
        try? modelContext.delete(model: IIDXTowerEntry.self)
        try? modelContext.save()
        #endif

        debugPrint("Migration from SwiftData to SQLite completed")
        await MainActor.run {
            progressAlertManager.hide()
            NotificationCenter.default.post(name: .dataMigrationCompleted, object: nil)
        }
    }
}
