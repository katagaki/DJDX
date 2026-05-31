import Foundation
import SQLite

actor PolarisChordImporter {

    typealias DB = PolarisChordPlayDataDatabase

    func importJSON(
        json jsonString: String,
        to importToDate: Date,
        version: PolarisChordVersion
    ) -> AsyncStream<ImportProgress> {
        let (stream, continuation) = AsyncStream.makeStream(of: ImportProgress.self)
        guard let data = jsonString.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data),
              let rows = parsed as? [[String: Any]] else {
            debugPrint("[PolarisChordImport] payload is not a JSON array; aborting import")
            continuation.finish()
            return stream
        }
        saveStringToFile(jsonString, appending: "-PolarisChord")
        debugPrint("[PolarisChordImport] parsed rows:", rows.count)
        importRows(rows, to: importToDate, version: version, continuation: continuation)
        continuation.finish()
        return stream
    }

    func importRows(
        _ jsonRows: [[String: Any]],
        to importToDate: Date,
        version: PolarisChordVersion,
        continuation: AsyncStream<ImportProgress>.Continuation
    ) {
        guard let database = try? DB.shared.getWriteConnection() else { return }
        let importGroupID = prepareImportGroup(
            database: database,
            importToDate: importToDate,
            version: version
        )

        let total = jsonRows.count
        var processed = 0
        var skipped = 0
        try? database.transaction {
            for jsonRow in jsonRows {
                let record = PolarisChordSongRecord(jsonRow: jsonRow)
                guard !record.title.isEmpty else { skipped += 1; continue }
                Self.insertSongRecord(database: database, record: record, importGroupID: importGroupID)
                processed += 1
                continuation.yield(.init(nil, nil, processed, total))
            }
        }
        debugPrint("[PolarisChordImport] inserted:", processed, "skipped:", skipped,
                   "importGroupID:", importGroupID)
    }

    func prepareImportGroup(
        database: Connection,
        importToDate: Date,
        version: PolarisChordVersion
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

    static func insertSongRecord(
        database: Connection,
        record: PolarisChordSongRecord,
        importGroupID: String
    ) {
        _ = try? database.run(DB.songRecordTable.insert(
            DB.srImportGroupID <- importGroupID,
            DB.srTitle <- record.title,
            DB.srMusicID <- record.musicID,
            DB.srCategory <- record.category,
            DB.srDifficulty <- record.difficulty,
            DB.srLevel <- record.level,
            DB.srAchievementRate <- record.achievementRate,
            DB.srScore <- record.score,
            DB.srClearType <- record.clearType,
            DB.srGrade <- record.grade
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

    func saveStringToFile(_ contents: String, appending suffix: String? = nil) {
        guard let documentsDirectoryURL = FileManager
            .default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let dateString = dateFormatter.string(from: .now)
        let fileName = "\(dateString)\(suffix ?? "").json"
        let fileURL = documentsDirectoryURL.appendingPathComponent(fileName, conformingTo: .json)
        try? contents.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
