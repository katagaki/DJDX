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

    let dateFormat = "yyyy-MM-dd-HH-mm-ss"

    // MARK: CSV Import

    func importSampleCSV(
        to importToDate: Date,
        for playType: IIDXPlayType
    ) -> AsyncStream<ImportProgress> {
        let (stream, continuation) = AsyncStream.makeStream(of: ImportProgress.self)
        continuation.yield(.init(0, 1, 1, 1))
        try? modelContext.transaction {
            importCSV(
                url: Bundle.main.url(forResource: "SampleData", withExtension: "csv"),
                to: importToDate,
                for: playType,
                from: .sparkleShower,
                continuation: continuation
            )
        }
        continuation.finish()
        return stream
    }

    func importCSVs(
        urls: [URL],
        to importToDate: Date,
        for playType: IIDXPlayType,
        from version: IIDXVersion
    ) -> AsyncStream<ImportProgress> {
        let (stream, continuation) = AsyncStream.makeStream(of: ImportProgress.self)
        var processedCount = 0
        let totalCount = urls.count
        continuation.yield(.init(0, totalCount))

        try? modelContext.transaction {
            for url in urls {
                processedCount += 1
                continuation.yield(.init(processedCount, totalCount))

                let isAccessSuccessful = url.startAccessingSecurityScopedResource()
                if isAccessSuccessful {
                    importCSV(
                        url: url,
                        to: importToDate,
                        for: playType,
                        from: version,
                        continuation: continuation
                    )
                }
                url.stopAccessingSecurityScopedResource()
            }
            continuation.finish()
        }
        return stream
    }

    func importCSV(
        url: URL?,
        to importToDate: Date,
        for playType: IIDXPlayType,
        from version: IIDXVersion,
        continuation: AsyncStream<ImportProgress>.Continuation
    ) {
        if let urlOfData: URL = url, let stringFromData: String = try? String(contentsOf: urlOfData) {
            let parsedCSV = CSwiftV(with: stringFromData)
            if let keyedRows = parsedCSV.keyedRows {

                // 1. Determine whether to use date from filename
                let fileNameWithoutExtension = urlOfData.deletingPathExtension().lastPathComponent
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = dateFormat

                if let date = dateFormatter.date(from: fileNameWithoutExtension) {
                    // 2. Import to date from filename
                    importCSV(
                        keyedRows,
                        to: date,
                        for: playType,
                        from: version,
                        continuation: continuation
                    )
                } else {
                    // 2. Import to selected date
                    saveCSVStringToFile(stringFromData)
                    importCSV(
                        keyedRows,
                        to: importToDate,
                        for: playType,
                        from: version,
                        continuation: continuation
                    )
                }
            }
        }
    }

    func importCSV(
        csv csvString: String,
        to importToDate: Date,
        for playType: IIDXPlayType,
        from version: IIDXVersion
    ) -> AsyncStream<ImportProgress> {
        let (stream, continuation) = AsyncStream.makeStream(of: ImportProgress.self)
        saveCSVStringToFile(csvString)
        let parsedCSV = CSwiftV(with: csvString)
        if let keyedRows = parsedCSV.keyedRows {
            try? modelContext.transaction {
                importCSV(
                    keyedRows,
                    to: importToDate,
                    for: playType,
                    from: version,
                    continuation: continuation
                )
            }
        }
        continuation.finish()
        return stream
    }

    func importCSV(
        _ keyedRows: [[String: String]],
        to importToDate: Date,
        for playType: IIDXPlayType,
        from version: IIDXVersion,
        continuation: AsyncStream<ImportProgress>.Continuation
    ) {
        let importGroup = prepareImportGroupForPartialImport(
            importToDate: importToDate,
            playType: playType,
            version: version
        )
        modelContext.insert(importGroup)

        let totalNumberOfKeyedRows = keyedRows.count
        var numberOfKeyedRowsProcessed = 0
        for keyedRow in keyedRows {
            let songRecord: IIDXSongRecord = IIDXSongRecord(csvRowData: keyedRow)
            modelContext.insert(songRecord)
            songRecord.importGroup = importGroup
            songRecord.playType = playType
            numberOfKeyedRowsProcessed += 1
            continuation.yield(.init(nil, nil, numberOfKeyedRowsProcessed, totalNumberOfKeyedRows))
        }
    }

    // MARK: Other Import Stuff

    func saveCSVStringToFile(_ csvString: String) {
        if let documentsDirectoryURL: URL = FileManager
        .default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = dateFormat
            let dateString = dateFormatter.string(from: .now)
            let csvFile = documentsDirectoryURL.appendingPathComponent("\(dateString).csv",
                                                                       conformingTo: .commaSeparatedText)
            try? csvString.write(to: csvFile, atomically: true, encoding: .utf8)
        }
    }

    func prepareImportGroupForPartialImport(
        importToDate: Date,
        playType: IIDXPlayType,
        version: IIDXVersion
    ) -> ImportGroup {
        let fetchDescriptor = FetchDescriptor<ImportGroup>(
            predicate: importGroups(from: importToDate)
        )
        // Find existing import group and return it after cleaning it up
        if let importGroupsOnSelectedDate: [ImportGroup] = try? modelContext.fetch(fetchDescriptor),
           let importGroup = importGroupsOnSelectedDate.first,
           let songRecords: [IIDXSongRecord] = importGroup.iidxData {
            for songRecord in songRecords where songRecord.playType == playType {
                modelContext.delete(songRecord)
            }
            return importGroup
        }
        // If all conditions fail, create new import group and return it
        let newImportGroup = ImportGroup(importDate: importToDate, iidxData: [], iidxVersion: version)
        modelContext.insert(newImportGroup)
        return newImportGroup
    }

    func importGroups(from startDate: Date) -> Predicate<ImportGroup> {
        let startOfDay = Calendar.current.startOfDay(for: startDate)
        var components = DateComponents()
        components.day = 1
        components.second = -1
        let endDate: Date = Calendar.current.date(byAdding: components, to: startOfDay)!
        return #Predicate<ImportGroup> {
            $0.importDate >= startOfDay && $0.importDate <= endDate
        }
    }
}
