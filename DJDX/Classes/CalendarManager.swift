//
//  CalendarManager.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/23.
//

import Foundation
import SwiftData

class CalendarManager: ObservableObject {

    let defaults = UserDefaults.standard
    let selectedDateKey = "CalendarManager.SelectedDate"

    @Published var selectedDate: Date
    @Published var didUserRecentlyImportSomeData: Bool = false

    init(selectedDate: Date? = nil) {
        if let selectedDate = defaults.object(forKey: selectedDateKey) as? Date {
            self.selectedDate = selectedDate
        } else {
            self.selectedDate = .now
        }
    }

    func saveToDefaults() {
        defaults.setValue(selectedDate, forKey: selectedDateKey)
        defaults.synchronize()
    }

    func loadCSVData(reportingTo progressAlertManager: ProgressAlertManager,
                     from url: URL? = Bundle.main.url(forResource: "SampleData", withExtension: "csv")) async {
        await MainActor.run {
            progressAlertManager.show(title: "Alert.Importing.Title", message: "Alert.Importing.Text")
        }
        if let urlOfData: URL = url, let stringFromData: String = try? String(contentsOf: urlOfData) {
            let modelContext = ModelContext(sharedModelContainer)
            let parsedCSV = CSwiftV(with: stringFromData)
            if let keyedRows = parsedCSV.keyedRows {
                // Delete selected date's import group
                let fetchDescriptor = FetchDescriptor<ImportGroup>(
                    predicate: importGroups(in: self)
                    )
                if let importGroupsOnSelectedDate: [ImportGroup] = try? modelContext.fetch(fetchDescriptor) {
                    for importGroup in importGroupsOnSelectedDate {
                        modelContext.delete(importGroup)
                    }
                }
                // Create new import group for selected date
                let newImportGroup: ImportGroup = ImportGroup(importDate: selectedDate, iidxData: [])
                modelContext.insert(newImportGroup)
                try? modelContext.save()
                // Read song records
                var numberOfKeyedRowsProcessed = 0
                try? modelContext.transaction {
                    for keyedRow in keyedRows {
                        debugPrint("Processing keyed row \(numberOfKeyedRowsProcessed)")
                        let scoreForSong: IIDXSongRecord = IIDXSongRecord(csvRowData: keyedRow)
                        modelContext.insert(scoreForSong)
                        scoreForSong.importGroup = newImportGroup
                        numberOfKeyedRowsProcessed += 1
                        Task { [numberOfKeyedRowsProcessed] in
                            await MainActor.run {
                                progressAlertManager.updateProgress(numberOfKeyedRowsProcessed * 100 / keyedRows.count)
                            }
                        }
                    }
                }
                try? modelContext.save()
            }
        }
        await finishLoadingCSVData(progressAlertManager)
    }

    func loadCSVData(reportingTo progressAlertManager: ProgressAlertManager, using csvString: String, for playType: IIDXPlayType) async {
        if let documentsDirectoryURL: URL = FileManager
            .default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
            let dateString = dateFormatter.string(from: .now)
            let csvFile = documentsDirectoryURL.appendingPathComponent("\(dateString).csv",
                                                                       conformingTo: .commaSeparatedText)
            try? csvString.write(to: csvFile, atomically: true, encoding: .utf8)
        }
        let parsedCSV = CSwiftV(with: csvString)
        if let keyedRows = parsedCSV.keyedRows {
            let modelContext = ModelContext(sharedModelContainer)
            var shouldCreateImportGroup = true
            var importGroupToUse: ImportGroup?
            // Delete selected date's import groups' song records that match the import type
            let fetchDescriptor = FetchDescriptor<ImportGroup>(
                predicate: importGroups(in: self)
            )
            if let importGroupsOnSelectedDate: [ImportGroup] = try? modelContext.fetch(fetchDescriptor) {
                for importGroup in importGroupsOnSelectedDate {
                    shouldCreateImportGroup = false
                    importGroupToUse = importGroup
                    if let songRecords: [IIDXSongRecord] = importGroup.iidxData {
                        for songRecord in songRecords where songRecord.playType == playType {
                            modelContext.delete(songRecord)
                        }
                    }
                }
            }
            let importDate = selectedDate
            try? modelContext.transaction { [playType] in
                var importGroup: ImportGroup?
                if shouldCreateImportGroup {
                    // Create new import group for selected date
                    let newImportGroup = ImportGroup(importDate: importDate, iidxData: [])
                    modelContext.insert(newImportGroup)
                    importGroup = newImportGroup
                } else {
                    if let importGroupToUse {
                        importGroup = importGroupToUse
                    }
                }
                if let importGroup {
                    // Read song records
                    var numberOfKeyedRowsProcessed = 0
                    for keyedRow in keyedRows {
                        debugPrint("Processing keyed row \(numberOfKeyedRowsProcessed)")
                        let scoreForSong: IIDXSongRecord = IIDXSongRecord(csvRowData: keyedRow)
                        modelContext.insert(scoreForSong)
                        scoreForSong.importGroup = importGroup
                        scoreForSong.playType = playType
                        numberOfKeyedRowsProcessed += 1
                        Task { [numberOfKeyedRowsProcessed] in
                            await MainActor.run {
                                progressAlertManager.updateProgress(
                                    numberOfKeyedRowsProcessed * 100 / keyedRows.count
                                )
                            }
                        }
                    }
                }
            }
            try? modelContext.save()
        }
        await finishLoadingCSVData(progressAlertManager)
    }

    func finishLoadingCSVData(_ progressAlertManager: ProgressAlertManager) async {
        await MainActor.run {
            didUserRecentlyImportSomeData = true
            progressAlertManager.hide()
        }
    }

    func allImportGroups(in modelContext: ModelContext) -> [ImportGroup] {
        var fetchDescriptor = FetchDescriptor<ImportGroup>(
            sortBy: [SortDescriptor<ImportGroup>(\.importDate, order: .reverse)]
        )
        fetchDescriptor.relationshipKeyPathsForPrefetching = []
        return (try? modelContext.fetch(fetchDescriptor)) ?? []
    }

    func latestAvailableIIDXSongRecords(in modelContext: ModelContext) -> [IIDXSongRecord] {
        let importGroupsForSelectedDate: [ImportGroup] = (try? modelContext.fetch(
            FetchDescriptor<ImportGroup>(
                predicate: importGroups(in: self),
                sortBy: [SortDescriptor(\.importDate, order: .forward)]
            )
        )) ?? []
        var importGroupID: String?
        if let importGroupForSelectedDate = importGroupsForSelectedDate.first {
            // Use selected date's import group
            importGroupID = importGroupForSelectedDate.id
        } else {
            // Use latest available import group
            let allImportGroups: [ImportGroup] = (try? modelContext.fetch(
                FetchDescriptor<ImportGroup>(
                    sortBy: [SortDescriptor(\.importDate, order: .forward)]
                )
            )) ?? []
            var importGroupClosestToTheSelectedDate: ImportGroup?
            for importGroup in allImportGroups {
                if importGroup.importDate <= selectedDate {
                    importGroupClosestToTheSelectedDate = importGroup
                } else {
                    break
                }
            }
            if let importGroupClosestToTheSelectedDate {
                importGroupID = importGroupClosestToTheSelectedDate.id
            }
        }
        if let importGroupID {
            let songRecordsInImportGroup: [IIDXSongRecord] = (try? modelContext.fetch(
                FetchDescriptor<IIDXSongRecord>(
                    predicate: #Predicate<IIDXSongRecord> {
                        $0.importGroup?.id == importGroupID
                    },
                    sortBy: [SortDescriptor(\.title, order: .forward)]
                )
            )) ?? []
            return songRecordsInImportGroup
        }
        return []
    }
}
