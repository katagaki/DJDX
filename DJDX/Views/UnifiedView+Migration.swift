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
        let importGroups: [ImportGroup] = (try? modelContext.fetch(
            FetchDescriptor<ImportGroup>(
                sortBy: [SortDescriptor(\.importDate, order: .forward)]
            )
        )) ?? []

        guard !importGroups.isEmpty else {
            UserDefaults.standard.set(true, forKey: "Internal.DataMigrationDeleteOldSQLiteData")
            return
        }

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

        try? await Task.sleep(for: .milliseconds(500))

        let importer = DataImporter()

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

        await importer.migrateSongs(songs)
        await importer.migrateTowerEntries(towerEntries)

        #if DEBUG
        try? modelContext.delete(model: IIDXSongRecord.self)
        try? modelContext.delete(model: ImportGroup.self)
        try? modelContext.delete(model: IIDXSong.self)
        try? modelContext.delete(model: IIDXTowerEntry.self)
        try? modelContext.save()
        #endif

        await MainActor.run {
            progressAlertManager.hide()
            NotificationCenter.default.post(name: .dataMigrationCompleted, object: nil)
        }
    }
}
