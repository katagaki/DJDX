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

    func importCSV(url: URL? = Bundle.main.url(forResource: "SampleData", withExtension: "csv"),
                   reportingTo progressAlertManager: ProgressAlertManager, for playType: IIDXPlayType) async {
        await MainActor.run {
            progressAlertManager.show(title: "Alert.Importing.Title", message: "Alert.Importing.Text")
        }
        if let urlOfData: URL = url, let stringFromData: String = try? String(contentsOf: urlOfData) {
            saveCSVStringToFile(stringFromData)
            let parsedCSV = CSwiftV(with: stringFromData)
            if let keyedRows = parsedCSV.keyedRows {
                importCSV(keyedRows: keyedRows, reportingTo: progressAlertManager, playType: playType)
            }
        }
        await finishImport(progressAlertManager)
    }

    func importCSV(csvString: String,
                   reportingTo progressAlertManager: ProgressAlertManager, for playType: IIDXPlayType) async {
        await MainActor.run {
            progressAlertManager.show(title: "Alert.Importing.Title", message: "Alert.Importing.Text")
        }
        saveCSVStringToFile(csvString)
        let parsedCSV = CSwiftV(with: csvString)
        if let keyedRows = parsedCSV.keyedRows {
            importCSV(keyedRows: keyedRows, reportingTo: progressAlertManager, playType: playType)
        }
        await finishImport(progressAlertManager)
    }

    func importCSV(keyedRows: [[String: String]],
                   reportingTo progressAlertManager: ProgressAlertManager, playType: IIDXPlayType) {
        let modelContext = ModelContext(sharedModelContainer)
        try? modelContext.transaction { [playType] in
            let importGroup = prepareImportGroupForPartialImport(modelContext, playType: playType)
            var numberOfKeyedRowsProcessed = 0
            for keyedRow in keyedRows {
                debugPrint("Processing keyed row \(numberOfKeyedRowsProcessed)")
                let songRecord: IIDXSongRecord = IIDXSongRecord(csvRowData: keyedRow)
                modelContext.insert(songRecord)
                songRecord.importGroup = importGroup
                songRecord.playType = playType
                numberOfKeyedRowsProcessed += 1
                Task { [numberOfKeyedRowsProcessed] in
                    await MainActor.run {
                        progressAlertManager.updateProgress(numberOfKeyedRowsProcessed * 100 / keyedRows.count
                        )
                    }
                }
            }
        }
        try? modelContext.save()
    }

    func finishImport(_ progressAlertManager: ProgressAlertManager) async {
        await MainActor.run {
            didUserRecentlyImportSomeData = true
            progressAlertManager.hide()
        }
    }

    func saveCSVStringToFile(_ csvString: String) {
        if let documentsDirectoryURL: URL = FileManager
        .default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
            let dateString = dateFormatter.string(from: .now)
            let csvFile = documentsDirectoryURL.appendingPathComponent("\(dateString).csv",
                                                                       conformingTo: .commaSeparatedText)
            try? csvString.write(to: csvFile, atomically: true, encoding: .utf8)
        }
    }

    func prepareImportGroupForPartialImport(_ modelContext: ModelContext, playType: IIDXPlayType) -> ImportGroup {
        let fetchDescriptor = FetchDescriptor<ImportGroup>(
            predicate: importGroups(in: self)
        )
        // Find existing import group and return it after cleaning it up
        if let importGroupsOnSelectedDate: [ImportGroup] = try? modelContext.fetch(fetchDescriptor) {
            for importGroup in importGroupsOnSelectedDate {
                if let songRecords: [IIDXSongRecord] = importGroup.iidxData {
                    for songRecord in songRecords where songRecord.playType == playType {
                        modelContext.delete(songRecord)
                    }
                }
                return importGroup
            }
        }
        // If all conditions fail, create new import group and return it
        let newImportGroup = ImportGroup(importDate: selectedDate, iidxData: [])
        modelContext.insert(newImportGroup)
        return newImportGroup
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
