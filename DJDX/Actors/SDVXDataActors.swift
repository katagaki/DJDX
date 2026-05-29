//
//  SDVXDataActors.swift
//  DJDX
//
//  Created by Claude on 2026/05/30.
//

import Foundation
import SQLite

actor SDVXDataFetcher {

    typealias DB = SDVXPlayDataDatabase

    // MARK: Import Groups

    func latestImportGroupID() -> String? {
        guard let database = try? DB.shared.getReadConnection() else { return nil }
        let query = DB.importGroupTable.order(DB.igImportDate.desc).limit(1)
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
}

actor SDVXDataImporter {

    typealias DB = SDVXPlayDataDatabase

    func importCSV(
        csv csvString: String,
        to importToDate: Date,
        version: SDVXVersion
    ) -> AsyncStream<ImportProgress> {
        let (stream, continuation) = AsyncStream.makeStream(of: ImportProgress.self)
        let parsedCSV = CSwiftV(with: csvString)
        if let keyedRows = parsedCSV.keyedRows {
            importRows(keyedRows, to: importToDate, version: version, continuation: continuation)
        }
        continuation.finish()
        return stream
    }

    func importRows(
        _ keyedRows: [[String: String]],
        to importToDate: Date,
        version: SDVXVersion,
        continuation: AsyncStream<ImportProgress>.Continuation
    ) {
        guard let database = try? DB.shared.getWriteConnection() else { return }
        let importGroupID = prepareImportGroup(
            database: database,
            importToDate: importToDate,
            version: version
        )

        let total = keyedRows.count
        var processed = 0

        try? database.transaction {
            for keyedRow in keyedRows {
                let record = SDVXSongRecord(csvRowData: keyedRow)
                guard !record.title.isEmpty else { continue }
                Self.insertSongRecord(database: database, record: record, importGroupID: importGroupID)
                processed += 1
                continuation.yield(.init(nil, nil, processed, total))
            }
        }
    }

    func prepareImportGroup(
        database: Connection,
        importToDate: Date,
        version: SDVXVersion
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

    static func insertSongRecord(database: Connection, record: SDVXSongRecord, importGroupID: String) {
        _ = try? database.run(DB.songRecordTable.insert(
            DB.srImportGroupID <- importGroupID,
            DB.srTitle <- record.title,
            DB.srDifficulty <- record.difficulty,
            DB.srLevel <- record.level,
            DB.srClearType <- record.clearType,
            DB.srGrade <- record.grade,
            DB.srHighScore <- record.highScore,
            DB.srEXScore <- record.exScore,
            DB.srPlayCount <- record.playCount,
            DB.srClearCount <- record.clearCount,
            DB.srUltimateChainCount <- record.ultimateChainCount,
            DB.srPerfectCount <- record.perfectCount
        ))
    }

    func deleteAllScoreData() {
        guard let database = try? DB.shared.getWriteConnection() else { return }
        _ = try? database.run(DB.songRecordTable.delete())
        _ = try? database.run(DB.importGroupTable.delete())
    }
}
