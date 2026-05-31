import Foundation
import SQLite

actor SDVXDataImporter {

    typealias DB = SDVXPlayDataDatabase

    func importSampleCSV(to importToDate: Date, version: SDVXVersion) -> AsyncStream<ImportProgress> {
        let (stream, continuation) = AsyncStream.makeStream(of: ImportProgress.self)
        if let url = Bundle.main.url(forResource: "SampleDataSDVX", withExtension: "csv"),
           let csvString = try? String(contentsOf: url, encoding: .utf8) {
            let sanitized = csvString.hasPrefix("\u{FEFF}") ? String(csvString.dropFirst()) : csvString
            let parsedCSV = CSwiftV(with: sanitized)
            if let keyedRows = parsedCSV.keyedRows {
                importRows(keyedRows, to: importToDate, version: version, continuation: continuation)
            }
        } else {
            debugPrint("[SDVXImport] sample data CSV not found in bundle")
        }
        continuation.finish()
        return stream
    }

    func importCSV(
        csv csvString: String,
        to importToDate: Date,
        version: SDVXVersion
    ) -> AsyncStream<ImportProgress> {
        let (stream, continuation) = AsyncStream.makeStream(of: ImportProgress.self)
        // Strip a leading UTF-8 BOM so the first CSV header (楽曲名) keys correctly.
        let sanitized = csvString.hasPrefix("\u{FEFF}") ? String(csvString.dropFirst()) : csvString
        // Guard against a non-CSV payload (e.g. an HTML page) being passed in.
        guard sanitized.contains("楽曲名") else {
            debugPrint("[SDVXImport] payload is not SDVX CSV; aborting import")
            continuation.finish()
            return stream
        }
        // Back up the raw CSV to the documents directory, like the IIDX importer.
        saveCSVStringToFile(sanitized, appending: "-SDVX")
        debugPrint("[SDVXImport] csv length:", sanitized.count,
                   "first line:", sanitized.split(separator: "\n").first ?? "<none>")
        let parsedCSV = CSwiftV(with: sanitized)
        if let keyedRows = parsedCSV.keyedRows {
            debugPrint("[SDVXImport] parsed headers:", parsedCSV.headers)
            debugPrint("[SDVXImport] parsed rows:", keyedRows.count)
            importRows(keyedRows, to: importToDate, version: version, continuation: continuation)
        } else {
            debugPrint("[SDVXImport] CSwiftV produced no keyed rows")
        }
        continuation.finish()
        return stream
    }

    func importRows(
        _ keyedRows: [[String: String]],
        to importToDate: Date,
        version: SDVXVersion,
        continuation: AsyncStream<ImportProgress>.Continuation
    ) {
        guard let database = try? DB.shared.getWriteConnection() else { return }
        let importGroupID = prepareImportGroup(
            database: database,
            importToDate: importToDate,
            version: version
        )

        let total = keyedRows.count
        var processed = 0

        var skipped = 0
        try? database.transaction {
            for keyedRow in keyedRows {
                let record = SDVXSongRecord(csvRowData: keyedRow)
                guard !record.title.isEmpty else { skipped += 1; continue }
                Self.insertSongRecord(database: database, record: record, importGroupID: importGroupID)
                processed += 1
                continuation.yield(.init(nil, nil, processed, total))
            }
        }
        debugPrint("[SDVXImport] inserted:", processed, "skipped:", skipped,
                   "importGroupID:", importGroupID)
    }

    func prepareImportGroup(
        database: Connection,
        importToDate: Date,
        version: SDVXVersion
    ) -> String {
        let startOfDay = Calendar.current.startOfDay(for: importToDate)
        let startOfNextDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let query = DB.importGroupTable
            .filter(DB.igImportDate >= startOfDay.timeIntervalSince1970
                    && DB.igImportDate < startOfNextDay.timeIntervalSince1970)
            .limit(1)

        if let row = try? database.pluck(query) {
            let existingID = row[DB.igID]
            let deleteQuery = DB.songRecordTable.filter(DB.srImportGroupID == existingID)
            _ = try? database.run(deleteQuery.delete())
            return existingID
        }

        let newID = UUID().uuidString
        _ = try? database.run(DB.importGroupTable.insert(
            DB.igID <- newID,
            DB.igImportDate <- importToDate.timeIntervalSince1970,
            DB.igVersion <- version.rawValue
        ))
        return newID
    }

    static func insertSongRecord(database: Connection, record: SDVXSongRecord, importGroupID: String) {
        _ = try? database.run(DB.songRecordTable.insert(
            DB.srImportGroupID <- importGroupID,
            DB.srTitle <- record.title,
            DB.srDifficulty <- record.difficulty,
            DB.srLevel <- record.level,
            DB.srClearType <- record.clearType,
            DB.srGrade <- record.grade,
            DB.srHighScore <- record.highScore,
            DB.srEXScore <- record.exScore,
            DB.srPlayCount <- record.playCount,
            DB.srClearCount <- record.clearCount,
            DB.srUltimateChainCount <- record.ultimateChainCount,
            DB.srPerfectCount <- record.perfectCount
        ))
    }

    func deleteAllScoreData() {
        guard let database = try? DB.shared.getWriteConnection() else { return }
        _ = try? database.run(DB.songRecordTable.delete())
        _ = try? database.run(DB.importGroupTable.delete())
    }

    func deleteImportGroup(id: String) {
        guard let database = try? DB.shared.getWriteConnection() else { return }
        _ = try? database.run(DB.songRecordTable.filter(DB.srImportGroupID == id).delete())
        _ = try? database.run(DB.importGroupTable.filter(DB.igID == id).delete())
    }

    func saveCSVStringToFile(_ csvString: String, appending suffix: String? = nil) {
        guard let documentsDirectoryURL = FileManager
            .default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let dateString = dateFormatter.string(from: .now)
        let csvFileName = "\(dateString)\(suffix ?? "").csv"
        let csvFile = documentsDirectoryURL.appendingPathComponent(
            csvFileName, conformingTo: .commaSeparatedText
        )
        try? csvString.write(to: csvFile, atomically: true, encoding: .utf8)
    }
}
