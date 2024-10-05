//
//  DataImporter.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/09/21.
//

import Foundation
import SwiftData

@ModelActor
actor DataImporter {

    // MARK: CSV Import

    func importSampleCSV(
        to importToDate: Date,
        for playType: IIDXPlayType,
        didProgressUpdate: @escaping @Sendable (Int, Int) -> Void = { _, _ in }
    ) {
        importCSV(
            url: Bundle.main.url(forResource: "SampleData", withExtension: "csv"),
            to: importToDate,
            for: playType,
            didProgressUpdate: didProgressUpdate
        )
    }

    func importCSV(
        url: URL?,
        to importToDate: Date,
        for playType: IIDXPlayType,
        didProgressUpdate: @escaping @Sendable (Int, Int) -> Void = { _, _ in }
    ) {
        if let urlOfData: URL = url, let stringFromData: String = try? String(contentsOf: urlOfData) {
            saveCSVStringToFile(stringFromData)
            let parsedCSV = CSwiftV(with: stringFromData)
            if let keyedRows = parsedCSV.keyedRows {
                importCSV(keyedRows, to: importToDate, for: playType, didProgressUpdate: didProgressUpdate)
            }
        }
    }

    func importCSV(
        csv csvString: String,
        to importToDate: Date,
        for playType: IIDXPlayType,
        didProgressUpdate: @escaping @Sendable (Int, Int) -> Void = { _, _ in }
    ) {
        saveCSVStringToFile(csvString)
        let parsedCSV = CSwiftV(with: csvString)
        if let keyedRows = parsedCSV.keyedRows {
            importCSV(keyedRows, to: importToDate, for: playType, didProgressUpdate: didProgressUpdate)
        }
    }

    func importCSV(
        _ keyedRows: [[String: String]],
        to importToDate: Date,
        for playType: IIDXPlayType,
        didProgressUpdate: @escaping @Sendable (Int, Int) -> Void = { _, _ in }
    ) {
        try? modelContext.transaction {
            let importGroup = prepareImportGroupForPartialImport(importToDate: importToDate, playType: playType)
            modelContext.insert(importGroup)

            let totalNumberOfKeyedRows = keyedRows.count
            var numberOfKeyedRowsProcessed = 0
            for keyedRow in keyedRows {
                debugPrint("Processing keyed row \(numberOfKeyedRowsProcessed)")
                let songRecord: IIDXSongRecord = IIDXSongRecord(csvRowData: keyedRow)
                modelContext.insert(songRecord)
                songRecord.importGroup = importGroup
                songRecord.playType = playType
                numberOfKeyedRowsProcessed += 1
                didProgressUpdate(numberOfKeyedRowsProcessed, totalNumberOfKeyedRows)
            }
        }
        try? modelContext.save()
    }

    // MARK: Other Import Stuff

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

    func prepareImportGroupForPartialImport(importToDate: Date, playType: IIDXPlayType) -> ImportGroup {
        let fetchDescriptor = FetchDescriptor<ImportGroup>(
            predicate: importGroups(from: importToDate)
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
        let newImportGroup = ImportGroup(importDate: importToDate, iidxData: [])
        modelContext.insert(newImportGroup)
        return newImportGroup
    }
}
