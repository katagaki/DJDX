import Foundation
import SQLite

actor GITADORAReader {

    typealias DB = GITADORAPlayDataDatabase

    // MARK: Import Groups

    func latestImportGroupID() -> String? {
        guard let database = try? DB.shared.getReadConnection() else { return nil }
        let query = DB.importGroupTable.order(DB.igImportDate.desc).limit(1)
        return (try? database.pluck(query))?[DB.igID]
    }

    func latestImportGroupID(for version: GITADORAVersion) -> String? {
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

    func allImportGroups() -> [GITADORAImportGroupInfo] {
        guard let database = try? DB.shared.getReadConnection() else { return [] }
        let query = DB.importGroupTable.order(DB.igImportDate.desc)
        return (try? database.prepare(query).map { row in
            GITADORAImportGroupInfo(
                id: row[DB.igID],
                date: Date(timeIntervalSince1970: row[DB.igImportDate]),
                version: row[DB.igVersion].flatMap { GITADORAVersion(rawValue: $0) }
            )
        }) ?? []
    }

    func importGroups(for version: GITADORAVersion) -> [GITADORAImportGroupInfo] {
        allImportGroups().filter { $0.version == version }
    }

    // MARK: Song Records

    func songRecords(for importGroupID: String) -> [GITADORASongRecord] {
        guard let database = try? DB.shared.getReadConnection() else { return [] }
        let query = DB.songRecordTable
            .filter(DB.srImportGroupID == importGroupID)
            .order(DB.srTitle.asc)
        return (try? database.prepare(query).map { Self.songRecord(from: $0) }) ?? []
    }

    func latestSongRecords(for version: GITADORAVersion) -> [GITADORASongRecord] {
        guard let importGroupID = latestImportGroupID(for: version) else { return [] }
        return songRecords(for: importGroupID)
    }

    static func songRecord(from row: Row) -> GITADORASongRecord {
        let record = GITADORASongRecord()
        record.title = row[DB.srTitle]
        record.instrument = row[DB.srInstrument]
        record.difficulty = row[DB.srDifficulty]
        record.level = row[DB.srLevel]
        record.achievementRate = row[DB.srAchievementRate]
        record.score = row[DB.srScore]
        record.clearType = row[DB.srClearType]
        record.rank = row[DB.srRank]
        return record
    }
}
