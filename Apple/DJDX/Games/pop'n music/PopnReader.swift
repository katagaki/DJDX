import Foundation
import SQLite

actor PopnReader {

    typealias DB = PopnPlayDataDatabase

    // MARK: Import Groups

    func latestImportGroupID() -> String? {
        guard let database = try? DB.shared.getReadConnection() else { return nil }
        let query = DB.importGroupTable.order(DB.igImportDate.desc).limit(1)
        return (try? database.pluck(query))?[DB.igID]
    }

    func latestImportGroupID(for version: PopnVersion) -> String? {
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
        return (try? database.pluck(query))?[DB.igID]
    }

    func allImportGroups() -> [PopnImportGroupInfo] {
        guard let database = try? DB.shared.getReadConnection() else { return [] }
        let query = DB.importGroupTable.order(DB.igImportDate.desc)
        return (try? database.prepare(query).map { row in
            PopnImportGroupInfo(
                id: row[DB.igID],
                date: Date(timeIntervalSince1970: row[DB.igImportDate]),
                version: row[DB.igVersion].flatMap { PopnVersion(rawValue: $0) }
            )
        }) ?? []
    }

    func importGroups(for version: PopnVersion) -> [PopnImportGroupInfo] {
        allImportGroups().filter { $0.version == version }
    }

    // MARK: Song Records

    func songRecords(for importGroupID: String) -> [PopnSongRecord] {
        guard let database = try? DB.shared.getReadConnection() else { return [] }
        let query = DB.songRecordTable
            .filter(DB.srImportGroupID == importGroupID)
            .order(DB.srTitle.asc)
        return (try? database.prepare(query).map { Self.songRecord(from: $0) }) ?? []
    }

    func latestSongRecords(for version: PopnVersion) -> [PopnSongRecord] {
        guard let importGroupID = latestImportGroupID(for: version) else { return [] }
        return songRecords(for: importGroupID)
    }

    static func songRecord(from row: Row) -> PopnSongRecord {
        let record = PopnSongRecord()
        record.title = row[DB.srTitle]
        record.genre = row[DB.srGenre]
        record.artist = row[DB.srArtist]
        record.difficulty = row[DB.srDifficulty]
        record.level = row[DB.srLevel]
        record.score = row[DB.srScore]
        record.medal = row[DB.srMedal]
        record.rank = row[DB.srRank]
        return record
    }
}
