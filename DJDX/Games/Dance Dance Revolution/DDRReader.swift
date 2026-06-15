import Foundation
import SQLite

actor DDRReader {

    typealias DB = DDRPlayDataDatabase

    // MARK: Import Groups

    func latestImportGroupID() -> String? {
        guard let database = try? DB.shared.getReadConnection() else { return nil }
        let query = DB.importGroupTable.order(DB.igImportDate.desc).limit(1)
        return (try? database.pluck(query))?[DB.igID]
    }

    func latestImportGroupID(for version: DDRVersion) -> String? {
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

    func allImportGroups() -> [DDRImportGroupInfo] {
        guard let database = try? DB.shared.getReadConnection() else { return [] }
        let query = DB.importGroupTable.order(DB.igImportDate.desc)
        return (try? database.prepare(query).map { row in
            DDRImportGroupInfo(
                id: row[DB.igID],
                date: Date(timeIntervalSince1970: row[DB.igImportDate]),
                version: row[DB.igVersion].flatMap { DDRVersion(rawValue: $0) }
            )
        }) ?? []
    }

    func importGroups(for version: DDRVersion) -> [DDRImportGroupInfo] {
        allImportGroups().filter { $0.version == version }
    }

    // MARK: Song Records

    func songRecords(for importGroupID: String) -> [DDRSongRecord] {
        guard let database = try? DB.shared.getReadConnection() else { return [] }
        let query = DB.songRecordTable
            .filter(DB.srImportGroupID == importGroupID)
            .order(DB.srTitle.asc)
        let records = (try? database.prepare(query).map { Self.songRecord(from: $0) }) ?? []
        return applyMetadata(to: records)
    }

    // Fill level + debut version from the BEMANIWiki metadata, joined by compact title.
    private func applyMetadata(to records: [DDRSongRecord]) -> [DDRSongRecord] {
        let metaByTitle = loadMetaByTitle()
        guard !metaByTitle.isEmpty else { return records }
        for record in records {
            if let meta = metaByTitle[record.titleCompact()] {
                record.level = meta.level(style: record.styleEnum, difficulty: record.difficultyEnum)
                record.version = meta.version
            }
        }
        return records
    }

    private func loadMetaByTitle() -> [String: DDRSongMeta] {
        guard let database = try? DDRMetadataDatabase.shared.getReadConnection() else { return [:] }
        var result: [String: DDRSongMeta] = [:]
        if let rows = try? database.prepare(DDRMetadataDatabase.songMetaTable) {
            for row in rows {
                result[row[DDRMetadataDatabase.smTitleCompact]] = DDRMetadataImporter.meta(from: row)
            }
        }
        return result
    }

    func latestSongRecords() -> [DDRSongRecord] {
        guard let importGroupID = latestImportGroupID() else { return [] }
        return songRecords(for: importGroupID)
    }

    func latestSongRecords(for version: DDRVersion) -> [DDRSongRecord] {
        guard let importGroupID = latestImportGroupID(for: version) else { return [] }
        return songRecords(for: importGroupID)
    }

    func songRecords(on date: Date) -> [DDRSongRecord] {
        guard let importGroupID = importGroupID(for: date) else { return [] }
        return songRecords(for: importGroupID)
    }

    static func songRecord(from row: Row) -> DDRSongRecord {
        let record = DDRSongRecord()
        record.songIndex = row[DB.srSongIndex]
        record.title = row[DB.srTitle]
        record.style = row[DB.srStyle]
        record.difficulty = row[DB.srDifficulty]
        record.level = row[DB.srLevel]
        record.score = row[DB.srScore]
        record.rank = row[DB.srRank]
        record.clearKind = row[DB.srClearKind]
        record.flareSkill = row[DB.srFlareSkill]
        record.flareRank = row[DB.srFlareRank]
        record.jacketPath = row[DB.srJacketPath]
        return record
    }
}
