import Foundation
import SQLite

actor SDVXReader {

    typealias DB = SDVXPlayDataDatabase

    // MARK: Import Groups

    func latestImportGroupID() -> String? {
        guard let database = try? DB.shared.getReadConnection() else { return nil }
        let query = DB.importGroupTable.order(DB.igImportDate.desc).limit(1)
        return (try? database.pluck(query))?[DB.igID]
    }

    func latestImportGroupID(for version: SDVXVersion) -> String? {
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

    func allImportGroups() -> [SDVXImportGroupInfo] {
        guard let database = try? DB.shared.getReadConnection() else { return [] }
        let query = DB.importGroupTable.order(DB.igImportDate.desc)
        return (try? database.prepare(query).map { row in
            SDVXImportGroupInfo(
                id: row[DB.igID],
                date: Date(timeIntervalSince1970: row[DB.igImportDate]),
                version: row[DB.igVersion].flatMap { SDVXVersion(rawValue: $0) }
            )
        }) ?? []
    }

    // Import groups for a single version, newest-first (inherits allImportGroups' date-desc order).
    func importGroups(for version: SDVXVersion) -> [SDVXImportGroupInfo] {
        allImportGroups().filter { $0.version == version }
    }

    // MARK: Song Records

    func songRecords(for importGroupID: String) -> [SDVXSongRecord] {
        guard let database = try? DB.shared.getReadConnection() else { return [] }
        let query = DB.songRecordTable
            .filter(DB.srImportGroupID == importGroupID)
            .order(DB.srTitle.asc)
        return (try? database.prepare(query).map { Self.songRecord(from: $0) }) ?? []
    }

    func latestSongRecords() -> [SDVXSongRecord] {
        guard let importGroupID = latestImportGroupID() else { return [] }
        return songRecords(for: importGroupID)
    }

    func latestSongRecords(for version: SDVXVersion) -> [SDVXSongRecord] {
        guard let importGroupID = latestImportGroupID(for: version) else { return [] }
        return songRecords(for: importGroupID)
    }

    func songRecords(on date: Date) -> [SDVXSongRecord] {
        guard let importGroupID = importGroupID(for: date) else { return [] }
        return songRecords(for: importGroupID)
    }

    static func songRecord(from row: Row) -> SDVXSongRecord {
        let record = SDVXSongRecord()
        record.title = row[DB.srTitle]
        record.difficulty = row[DB.srDifficulty]
        record.level = row[DB.srLevel]
        record.clearType = row[DB.srClearType]
        record.grade = row[DB.srGrade]
        record.highScore = row[DB.srHighScore]
        record.exScore = row[DB.srEXScore]
        record.playCount = row[DB.srPlayCount]
        record.clearCount = row[DB.srClearCount]
        record.ultimateChainCount = row[DB.srUltimateChainCount]
        record.perfectCount = row[DB.srPerfectCount]
        return record
    }

    // MARK: sdvx.in Chart Index (external data source)

    func sdvxInChartCount() -> Int {
        guard let database = try? SDVXInDatabase.shared.getReadConnection() else { return 0 }
        return (try? database.scalar(SDVXInDatabase.chartTable.count)) ?? 0
    }

    // Resolves a play record's (title, difficulty) to the matching sdvx.in chart.
    // Matching is done on the normalized title plus the difficulty slot, since a
    // song has exactly one chart per slot.
    func sdvxInChart(title: String, difficulty: SDVXDifficulty) -> SDVXInChart? {
        guard let database = try? SDVXInDatabase.shared.getReadConnection() else { return nil }
        let query = SDVXInDatabase.chartTable
            .filter(SDVXInDatabase.chartTitleCompact == title.compact
                    && SDVXInDatabase.chartSlot == difficulty.sdvxInSlot)
            .limit(1)
        guard let row = try? database.pluck(query) else { return nil }
        return SDVXInChart(
            code: row[SDVXInDatabase.chartCode],
            slot: row[SDVXInDatabase.chartSlot],
            title: row[SDVXInDatabase.chartTitle],
            level: row[SDVXInDatabase.chartLevel]
        )
    }
}
