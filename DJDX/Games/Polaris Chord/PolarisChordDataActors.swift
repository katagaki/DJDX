import Foundation
import SQLite

actor PolarisChordDataFetcher {

    typealias DB = PolarisChordPlayDataDatabase

    // MARK: Import Groups

    func latestImportGroupID() -> String? {
        guard let database = try? DB.shared.getReadConnection() else { return nil }
        let query = DB.importGroupTable.order(DB.igImportDate.desc).limit(1)
        return (try? database.pluck(query))?[DB.igID]
    }

    func latestImportGroupID(for version: PolarisChordVersion) -> String? {
        guard let database = try? DB.shared.getReadConnection() else { return nil }
        let query = DB.importGroupTable
            .filter(DB.igVersion == version.rawValue)
            .order(DB.igImportDate.desc)
            .limit(1)
        return (try? database.pluck(query))?[DB.igID]
    }

    func importGroupID(for selectedDate: Date) -> String? {
        guard let database = try? DB.shared.getReadConnection() else { return nil }
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        let startOfNextDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let query = DB.importGroupTable
            .filter(DB.igImportDate >= startOfDay.timeIntervalSince1970
                    && DB.igImportDate < startOfNextDay.timeIntervalSince1970)
            .order(DB.igImportDate.asc)
            .limit(1)
        if let row = try? database.pluck(query) {
            return row[DB.igID]
        }
        // Fallback: closest earlier import group
        let allQuery = DB.importGroupTable.order(DB.igImportDate.asc)
        guard let rows = try? database.prepare(allQuery) else { return nil }
        var closestID: String?
        for row in rows {
            if row[DB.igImportDate] <= selectedDate.timeIntervalSince1970 {
                closestID = row[DB.igID]
            } else {
                break
            }
        }
        return closestID
    }

    func allImportDates() -> [Date] {
        guard let database = try? DB.shared.getReadConnection() else { return [] }
        let query = DB.importGroupTable.order(DB.igImportDate.desc)
        return (try? database.prepare(query).map {
            Date(timeIntervalSince1970: $0[DB.igImportDate])
        }) ?? []
    }

    func allImportGroups() -> [PolarisChordImportGroupInfo] {
        guard let database = try? DB.shared.getReadConnection() else { return [] }
        let query = DB.importGroupTable.order(DB.igImportDate.desc)
        return (try? database.prepare(query).map { row in
            PolarisChordImportGroupInfo(
                id: row[DB.igID],
                date: Date(timeIntervalSince1970: row[DB.igImportDate]),
                version: row[DB.igVersion].flatMap { PolarisChordVersion(rawValue: $0) }
            )
        }) ?? []
    }

    // MARK: Song Records

    func songRecords(for importGroupID: String) -> [PolarisChordSongRecord] {
        guard let database = try? DB.shared.getReadConnection() else { return [] }
        let query = DB.songRecordTable
            .filter(DB.srImportGroupID == importGroupID)
            .order(DB.srTitle.asc)
        return (try? database.prepare(query).map { Self.songRecord(from: $0) }) ?? []
    }

    func latestSongRecords() -> [PolarisChordSongRecord] {
        guard let importGroupID = latestImportGroupID() else { return [] }
        return songRecords(for: importGroupID)
    }

    func latestSongRecords(for version: PolarisChordVersion) -> [PolarisChordSongRecord] {
        guard let importGroupID = latestImportGroupID(for: version) else { return [] }
        return songRecords(for: importGroupID)
    }

    func songRecords(on date: Date) -> [PolarisChordSongRecord] {
        guard let importGroupID = importGroupID(for: date) else { return [] }
        return songRecords(for: importGroupID)
    }

    static func songRecord(from row: Row) -> PolarisChordSongRecord {
        let record = PolarisChordSongRecord()
        record.title = row[DB.srTitle]
        record.musicID = row[DB.srMusicID]
        record.category = row[DB.srCategory]
        record.difficulty = row[DB.srDifficulty]
        record.level = row[DB.srLevel]
        record.achievementRate = row[DB.srAchievementRate]
        record.score = row[DB.srScore]
        record.clearType = row[DB.srClearType]
        record.grade = row[DB.srGrade]
        return record
    }
}

actor PolarisChordDataImporter {

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

struct PolarisChordImportGroupInfo: Identifiable, Hashable {
    let id: String
    let date: Date
    let version: PolarisChordVersion?
}
