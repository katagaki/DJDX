import Foundation
import SQLite

actor GITADORAImporter {

    typealias DB = GITADORAPlayDataDatabase

    static let playerNameKey = "GITADORAProfile.PlayerName"

    static func skillKey(gameType: String) -> String {
        "GITADORAProfile.Skill.\(gameType)"
    }

    func importJSON(
        json jsonString: String,
        to importToDate: Date,
        version: GITADORAVersion
    ) -> AsyncStream<ImportProgress> {
        let (stream, continuation) = AsyncStream.makeStream(of: ImportProgress.self)
        guard let data = jsonString.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = parsed["rows"] as? [[String: Any]] else {
            debugPrint("[GITADORAImport] payload is not a JSON object with rows; aborting import")
            continuation.finish()
            return stream
        }
        if let profile = parsed["profile"] as? [String: Any] {
            Self.saveProfile(profile)
        }
        debugPrint("[GITADORAImport] parsed rows:", rows.count)
        importRows(rows, to: importToDate, version: version, continuation: continuation)
        continuation.finish()
        return stream
    }

    static func saveProfile(_ profile: [String: Any]) {
        if let name = (profile["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            UserDefaults.standard.set(name, forKey: playerNameKey)
        }
        if let skills = profile["skill"] as? [String: Any] {
            for (gameType, value) in skills {
                if let skill = value as? Double, skill > 0 {
                    UserDefaults.standard.set(String(format: "%.2f", skill), forKey: skillKey(gameType: gameType))
                } else if let skill = value as? Int, skill > 0 {
                    UserDefaults.standard.set(String(format: "%.2f", Double(skill)),
                                              forKey: skillKey(gameType: gameType))
                }
            }
        }
    }

    func importRows(
        _ jsonRows: [[String: Any]],
        to importToDate: Date,
        version: GITADORAVersion,
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
                let record = GITADORASongRecord(jsonRow: jsonRow)
                guard !record.title.isEmpty, record.difficultyEnum != .unknown else { continue }
                Self.insertSongRecord(database: database, record: record, importGroupID: importGroupID)
                processed += 1
                continuation.yield(.init(nil, nil, processed, total))
            }
        }
        debugPrint("[GITADORAImport] inserted:", processed, "importGroupID:", importGroupID)
    }

    func prepareImportGroup(
        database: Connection,
        importToDate: Date,
        version: GITADORAVersion
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
        record: GITADORASongRecord,
        importGroupID: String
    ) {
        _ = try? database.run(DB.songRecordTable.insert(
            DB.srImportGroupID <- importGroupID,
            DB.srTitle <- record.title,
            DB.srInstrument <- record.instrument,
            DB.srDifficulty <- record.difficulty,
            DB.srLevel <- record.level,
            DB.srAchievementRate <- record.achievementRate,
            DB.srScore <- record.score,
            DB.srClearType <- record.clearType,
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
