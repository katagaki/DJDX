//
//  ImportView+Functions.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/12/20.
//

import Foundation
import SwiftData

extension ImportView {

//    func countOfIIDXSongRecords(in importGroup: ImportGroup) -> Int {
//        let importGroupID = importGroup.id
//        let fetchDescriptor = FetchDescriptor<IIDXSongRecord>(
//            predicate: #Predicate<IIDXSongRecord> {
//                $0.importGroup?.id == importGroupID
//            }
//        )
//        return (try? modelContext.fetchCount(fetchDescriptor)) ?? 0
//    }

    func errorMessage(for reason: ImportFailedReason) -> String {
        switch reason {
        case .noPremiumCourse:
            return NSLocalizedString("Alert.Import.Error.Subtitle.NoPremiumCourse", comment: "")
        case .noEAmusementPass:
            return NSLocalizedString("Alert.Import.Error.Subtitle.NoEAmusementPass", comment: "")
        case .noPlayData:
            return NSLocalizedString("Alert.Import.Error.Subtitle.NoPlayData", comment: "")
        case .serverError:
            return NSLocalizedString("Alert.Import.Error.Subtitle.ServerError", comment: "")
        case .maintenance:
            return NSLocalizedString("Alert.Import.Error.Subtitle.Maintenance", comment: "")
        }
    }

    func deleteImport(_ indexSet: IndexSet) {
        var importGroupsToDelete: [ImportGroup] = []
        indexSet.forEach { index in
            importGroupsToDelete.append(importGroups[index])
        }
        try? modelContext.transaction {
            importGroupsToDelete.forEach { importGroup in
                modelContext.delete(importGroup)
            }
        }
    }

    func openCSVDownloadPage() {
        openURL(URL(
            string: "https://p.eagate.573.jp/game/2dx/\(iidxVersion.rawValue)/djdata/score_download.html"
        )!)
    }

    func importSampleCSV() {
        progressAlertManager.show(
            title: "Alert.Importing.Title",
            message: "Alert.Importing.Text"
        ) {
            Task {
                for await progress in await actor.importSampleCSV(
                    to: importToDate,
                    for: .single
                ) {
                    if let currentFileProgress = progress.currentFileProgress,
                        let currentFileTotal = progress.currentFileTotal {
                        let progress = (currentFileProgress * 100) / currentFileTotal
                        await MainActor.run {
                            progressAlertManager.updateProgress(progress)
                        }
                    }
                }
                await MainActor.run {
                    didImportSucceed = true
                    progressAlertManager.hide()
                }
            }
        }
    }

    func importCSVs(from urls: [URL]) {
        progressAlertManager.show(
            title: "Alert.Importing.Title",
            message: "Alert.Importing.Text"
        ) {
            Task {
                for await progress in await actor.importCSVs(
                    urls: urls,
                    to: importToDate,
                    for: importPlayType,
                    from: iidxVersion
                ) {
                    if let filesProcessed = progress.filesProcessed,
                       let fileCount = progress.fileCount {
                        await MainActor.run {
                            progressAlertManager.updateTitle("Alert.Importing.Title.\(filesProcessed).\(fileCount)")
                        }
                    }
                    if let currentFileProgress = progress.currentFileProgress,
                        let currentFileTotal = progress.currentFileTotal,
                       currentFileTotal > 0 {
                        let progress = (currentFileProgress * 100) / currentFileTotal
                        await MainActor.run {
                            progressAlertManager.updateProgress(progress)
                        }
                    }
                }
                await MainActor.run {
                    didImportSucceed = true
                    progressAlertManager.hide()
                }
            }
        }
    }
}
