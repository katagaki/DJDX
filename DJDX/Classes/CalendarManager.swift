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

    func loadCSVData(to modelContext: ModelContext,
                     from url: URL? = Bundle.main.url(forResource: "SampleData", withExtension: "csv")) {
        if let urlOfData: URL = url, let stringFromData: String = try? String(contentsOf: urlOfData) {
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
                for keyedRow in keyedRows {
                    let scoreForSong: IIDXSongRecord = IIDXSongRecord(csvRowData: keyedRow)
                    modelContext.insert(scoreForSong)
                    scoreForSong.importGroup = newImportGroup
                }
                try? modelContext.save()
            }
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
