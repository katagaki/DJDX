import Foundation
import SQLite

struct DDRScrapedRow: Decodable {
    let songIndex: String
    let title: String
    let jacket: String
    let style: String
    let difficulty: String
    let score: String
    let rank: String
    let clearKind: String
    let flareSkill: String
    let flareRank: String
}

actor DDRImporter {

    // swiftlint:disable:next type_name
    typealias DB = DDRPlayDataDatabase

    func importJSON(
        json jsonString: String,
        to importToDate: Date,
        version: DDRVersion
    ) -> AsyncStream<ImportProgress> {
        let (stream, continuation) = AsyncStream.makeStream(of: ImportProgress.self)
        guard let data = jsonString.data(using: .utf8),
              let rows = try? JSONDecoder().decode([DDRScrapedRow].self, from: data) else {
            debugPrint("[DDRImport] payload is not DDR JSON; aborting import")
            continuation.finish()
            return stream
        }
        importRows(rows, to: importToDate, version: version, continuation: continuation)
        continuation.finish()
        return stream
    }

    func importRows(
        _ rows: [DDRScrapedRow],
        to importToDate: Date,
        version: DDRVersion,
        continuation: AsyncStream<ImportProgress>.Continuation
    ) {
        guard let database = try? DB.shared.getWriteConnection() else { return }
        let importGroupID = prepareImportGroup(
            database: database,
            importToDate: importToDate,
            version: version
        )

        let total = rows.count
        var processed = 0
        var skipped = 0
        try? database.transaction {
            for row in rows {
                let record = Self.songRecord(from: row)
                guard !record.songIndex.isEmpty, !record.title.isEmpty else { skipped += 1; continue }
                Self.insertSongRecord(database: database, record: record, importGroupID: importGroupID)
                processed += 1
                continuation.yield(.init(nil, nil, processed, total))
            }
        }
        debugPrint("[DDRImport] inserted:", processed, "skipped:", skipped,
                   "importGroupID:", importGroupID)
    }

    static func songRecord(from row: DDRScrapedRow) -> DDRSongRecord {
        let record = DDRSongRecord()
        record.songIndex = row.songIndex
        record.title = row.title
        record.jacketPath = row.jacket
        record.style = (DDRPlayStyle(rawValue: row.style) ?? .single).rawValue
        record.difficulty = (DDRDifficulty(rawValue: row.difficulty) ?? .unknown).rawValue
        record.score = parseScore(row.score)
        record.rank = strippedStem(row.rank, prefix: "rank_s_")
        record.clearKind = strippedStem(row.clearKind, prefix: "cl_")
        record.flareSkill = parseScore(row.flareSkill)
        record.flareRank = strippedStem(row.flareRank, prefix: "flare_")
        return record
    }

    static func strippedStem(_ stem: String, prefix: String) -> String {
        var token = stem
        if token.hasPrefix(prefix) {
            token.removeFirst(prefix.count)
        }
        if token == "none" || token == "nodisp" || token.isEmpty {
            return ""
        }
        return token
    }

    static func parseScore(_ text: String) -> Int {
        Int(text.filter(\.isNumber)) ?? 0
    }

    func prepareImportGroup(
        database: Connection,
        importToDate: Date,
        version: DDRVersion
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

    static func insertSongRecord(database: Connection, record: DDRSongRecord, importGroupID: String) {
        _ = try? database.run(DB.songRecordTable.insert(
            DB.srImportGroupID <- importGroupID,
            DB.srSongIndex <- record.songIndex,
            DB.srTitle <- record.title,
            DB.srStyle <- record.style,
            DB.srDifficulty <- record.difficulty,
            DB.srLevel <- record.level,
            DB.srScore <- record.score,
            DB.srRank <- record.rank,
            DB.srClearKind <- record.clearKind,
            DB.srFlareSkill <- record.flareSkill,
            DB.srFlareRank <- record.flareRank,
            DB.srJacketPath <- record.jacketPath
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
