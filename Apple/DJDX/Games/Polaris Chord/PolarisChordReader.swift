import Foundation
import SQLite

actor PolarisChordReader {

    // swiftlint:disable:next type_name
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

    // Import groups for a single version, newest-first (inherits allImportGroups' date-desc order).
    func importGroups(for version: PolarisChordVersion) -> [PolarisChordImportGroupInfo] {
        allImportGroups().filter { $0.version == version }
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
