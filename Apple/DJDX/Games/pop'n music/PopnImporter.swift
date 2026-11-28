import Foundation
import SQLite

actor PopnImporter {

    typealias DB = PopnPlayDataDatabase

    func importJSON(
        json jsonString: String,
        to importToDate: Date,
        version: PopnVersion
    ) -> AsyncStream<ImportProgress> {
        let (stream, continuation) = AsyncStream.makeStream(of: ImportProgress.self)
        guard let data = jsonString.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = parsed["rows"] as? [[String: Any]] else {
            debugPrint("[PopnImport] payload is not a JSON object with rows; aborting import")
            continuation.finish()
            return stream
        }
        if let profile = parsed["profile"] as? [String: Any] {
            PopnProfile.save(profile, for: version)
        }
        debugPrint("[PopnImport] parsed rows:", rows.count)
        importRows(rows, to: importToDate, version: version, continuation: continuation)
        continuation.finish()
        return stream
    }

    func importRows(
        _ jsonRows: [[String: Any]],
        to importToDate: Date,
        version: PopnVersion,
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
        try? database.transaction {
            for jsonRow in jsonRows {
                let record = PopnSongRecord(jsonRow: jsonRow)
                guard !record.title.isEmpty, record.difficultyEnum != .unknown else { continue }
                Self.insertSongRecord(database: database, record: record, importGroupID: importGroupID)
                processed += 1
                continuation.yield(.init(nil, nil, processed, total))
            }
        }
        debugPrint("[PopnImport] inserted:", processed, "of", total, "importGroupID:", importGroupID)
    }

    func prepareImportGroup(
        database: Connection,
        importToDate: Date,
        version: PopnVersion
    ) -> String {
        let startOfDay = Calendar.current.startOfDay(for: importToDate)
        let startOfNextDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let query = DB.importGroupTable
            .filter(DB.igImportDate >= startOfDay.timeIntervalSince1970
                    && DB.igImportDate < startOfNextDay.timeIntervalSince1970
                    && DB.igVersion == version.rawValue)
            .limit(1)

        if let row = try? database.pluck(query) {
            let existingID = row[DB.igID]
            _ = try? database.run(DB.songRecordTable.filter(DB.srImportGroupID == existingID).delete())
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
        record: PopnSongRecord,
        importGroupID: String
    ) {
        _ = try? database.run(DB.songRecordTable.insert(
            DB.srImportGroupID <- importGroupID,
            DB.srTitle <- record.title,
            DB.srGenre <- record.genre,
            DB.srArtist <- record.artist,
            DB.srDifficulty <- record.difficulty,
            DB.srLevel <- record.level,
            DB.srScore <- record.score,
            DB.srMedal <- record.medal,
            DB.srRank <- record.rank
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
}
