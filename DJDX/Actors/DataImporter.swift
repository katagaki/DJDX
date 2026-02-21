//
//  DataImporter.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/09/21.
//

import Foundation
import SQLite

actor DataImporter {

    let dateFormat = "yyyy-MM-dd-HH-mm-ss"

    // MARK: CSV Import

    func importSampleCSV(
        to importToDate: Date,
        for playType: IIDXPlayType
    ) -> AsyncStream<ImportProgress> {
        let (stream, continuation) = AsyncStream.makeStream(of: ImportProgress.self)
        continuation.yield(.init(0, 1, 1, 1))
        importCSV(
            url: Bundle.main.url(forResource: "SampleData", withExtension: "csv"),
            to: importToDate,
            for: playType,
            from: .sparkleShower,
            continuation: continuation
        )
        continuation.finish()
        return stream
    }

    func importCSVs(
        urls: [URL],
        to importToDate: Date,
        for playType: IIDXPlayType,
        from version: IIDXVersion
    ) -> AsyncStream<ImportProgress> {
        let (stream, continuation) = AsyncStream.makeStream(of: ImportProgress.self)
        var processedCount = 0
        let totalCount = urls.count
        continuation.yield(.init(0, totalCount))

        for url in urls {
            processedCount += 1
            continuation.yield(.init(processedCount, totalCount))

            let isAccessSuccessful = url.startAccessingSecurityScopedResource()
            if isAccessSuccessful {
                importCSV(
                    url: url,
                    to: importToDate,
                    for: playType,
                    from: version,
                    continuation: continuation
                )
            }
            url.stopAccessingSecurityScopedResource()
        }
        continuation.finish()
        return stream
    }

    func importCSV(
        url: URL?,
        to importToDate: Date,
        for playType: IIDXPlayType,
        from version: IIDXVersion,
        continuation: AsyncStream<ImportProgress>.Continuation
    ) {
        if let urlOfData: URL = url, let stringFromData: String = try? String(contentsOf: urlOfData) {
            let parsedCSV = CSwiftV(with: stringFromData)
            if let keyedRows = parsedCSV.keyedRows {

                let fileNameWithoutExtension = urlOfData.deletingPathExtension().lastPathComponent
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = dateFormat

                if let date = dateFormatter.date(from: fileNameWithoutExtension) {
                    importCSV(
                        keyedRows,
                        to: date,
                        for: playType,
                        from: version,
                        continuation: continuation
                    )
                } else {
                    saveCSVStringToFile(stringFromData)
                    importCSV(
                        keyedRows,
                        to: importToDate,
                        for: playType,
                        from: version,
                        continuation: continuation
                    )
                }
            }
        }
    }

    func importCSV(
        csv csvString: String,
        to importToDate: Date,
        for importMode: IIDXImportMode,
        from version: IIDXVersion
    ) -> AsyncStream<ImportProgress> {
        let (stream, continuation) = AsyncStream.makeStream(of: ImportProgress.self)

        if let playType = importMode.playType {
            saveCSVStringToFile(csvString)
            let parsedCSV = CSwiftV(with: csvString)
            if let keyedRows = parsedCSV.keyedRows {
                importCSV(
                    keyedRows,
                    to: importToDate,
                    for: playType,
                    from: version,
                    continuation: continuation
                )
            }
        } else {
            saveCSVStringToFile(csvString, appending: "-Tower")
            let parsedCSV = CSwiftV(with: csvString)
            if let keyedRows = parsedCSV.keyedRows {
                importTowerCSV(keyedRows)
            }
        }

        continuation.finish()
        return stream
    }

    func importCSV(
        _ keyedRows: [[String: String]],
        to importToDate: Date,
        for playType: IIDXPlayType,
        from version: IIDXVersion,
        continuation: AsyncStream<ImportProgress>.Continuation
    ) {
        guard let database = try? PlayDataDatabase.shared.getWriteConnection() else { return }
        let importGroupID = prepareImportGroupForPartialImport(
            database: database,
            importToDate: importToDate,
            playType: playType,
            version: version
        )

        let totalNumberOfKeyedRows = keyedRows.count
        var numberOfKeyedRowsProcessed = 0

        try? database.transaction {
            for keyedRow in keyedRows {
                let songRecord = IIDXSongRecord(csvRowData: keyedRow)
                songRecord.playType = playType
                Self.insertSongRecord(database: database, record: songRecord, importGroupID: importGroupID)
                numberOfKeyedRowsProcessed += 1
                continuation.yield(.init(nil, nil, numberOfKeyedRowsProcessed, totalNumberOfKeyedRows))
            }
        }
    }

    // MARK: Other Import Stuff

    func saveCSVStringToFile(_ csvString: String, appending suffix: String? = nil) {
        if let documentsDirectoryURL: URL = FileManager
        .default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = dateFormat
            let dateString = dateFormatter.string(from: .now)
            let csvFileName = "\(dateString)\(suffix ?? "").csv"
            let csvFile = documentsDirectoryURL.appendingPathComponent(
                csvFileName, conformingTo: .commaSeparatedText
            )
            try? csvString.write(to: csvFile, atomically: true, encoding: .utf8)
        }
    }

    func prepareImportGroupForPartialImport(
        database: Connection,
        importToDate: Date,
        playType: IIDXPlayType,
        version: IIDXVersion
    ) -> String {
        let col = PlayDataDatabase.self
        let startOfDay = Calendar.current.startOfDay(for: importToDate)
        let startOfNextDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let query = col.importGroupTable
            .filter(col.igImportDate >= startOfDay.timeIntervalSince1970
                    && col.igImportDate < startOfNextDay.timeIntervalSince1970)
            .limit(1)

        if let row = try? database.pluck(query) {
            let existingID = row[col.igID]
            // Delete existing records for this playType
            let deleteQuery = col.songRecordTable
                .filter(col.srImportGroupID == existingID && col.srPlayType == playType.rawValue)
            _ = try? database.run(deleteQuery.delete())
            return existingID
        }

        // Create new import group
        let newID = UUID().uuidString
        _ = try? database.run(col.importGroupTable.insert(
            col.igID <- newID,
            col.igImportDate <- importToDate.timeIntervalSince1970,
            col.igIIDXVersion <- version.rawValue
        ))
        return newID
    }

    // MARK: Insert Helpers

    static func insertSongRecord(database: Connection, record: IIDXSongRecord, importGroupID: String) {
        let col = PlayDataDatabase.self
        _ = try? database.run(col.songRecordTable.insert(
            col.srImportGroupID <- importGroupID,
            col.srVersion <- record.version,
            col.srTitle <- record.title,
            col.srGenre <- record.genre,
            col.srArtist <- record.artist,
            col.srPlayCount <- record.playCount,
            col.srPlayType <- record.playType.rawValue,
            col.srLastPlayDate <- record.lastPlayDate.timeIntervalSince1970,
            // Beginner
            col.srBeginnerLevel <- record.beginnerScore.level.code(),
            col.srBeginnerDifficulty <- record.beginnerScore.difficulty,
            col.srBeginnerScore <- record.beginnerScore.score,
            col.srBeginnerPerfectGreatCount <- record.beginnerScore.perfectGreatCount,
            col.srBeginnerGreatCount <- record.beginnerScore.greatCount,
            col.srBeginnerMissCount <- record.beginnerScore.missCount,
            col.srBeginnerClearType <- record.beginnerScore.clearType,
            col.srBeginnerDJLevel <- record.beginnerScore.djLevel,
            // Normal
            col.srNormalLevel <- record.normalScore.level.code(),
            col.srNormalDifficulty <- record.normalScore.difficulty,
            col.srNormalScore <- record.normalScore.score,
            col.srNormalPerfectGreatCount <- record.normalScore.perfectGreatCount,
            col.srNormalGreatCount <- record.normalScore.greatCount,
            col.srNormalMissCount <- record.normalScore.missCount,
            col.srNormalClearType <- record.normalScore.clearType,
            col.srNormalDJLevel <- record.normalScore.djLevel,
            // Hyper
            col.srHyperLevel <- record.hyperScore.level.code(),
            col.srHyperDifficulty <- record.hyperScore.difficulty,
            col.srHyperScore <- record.hyperScore.score,
            col.srHyperPerfectGreatCount <- record.hyperScore.perfectGreatCount,
            col.srHyperGreatCount <- record.hyperScore.greatCount,
            col.srHyperMissCount <- record.hyperScore.missCount,
            col.srHyperClearType <- record.hyperScore.clearType,
            col.srHyperDJLevel <- record.hyperScore.djLevel,
            // Another
            col.srAnotherLevel <- record.anotherScore.level.code(),
            col.srAnotherDifficulty <- record.anotherScore.difficulty,
            col.srAnotherScore <- record.anotherScore.score,
            col.srAnotherPerfectGreatCount <- record.anotherScore.perfectGreatCount,
            col.srAnotherGreatCount <- record.anotherScore.greatCount,
            col.srAnotherMissCount <- record.anotherScore.missCount,
            col.srAnotherClearType <- record.anotherScore.clearType,
            col.srAnotherDJLevel <- record.anotherScore.djLevel,
            // Leggendaria
            col.srLeggendariaLevel <- record.leggendariaScore.level.code(),
            col.srLeggendariaDifficulty <- record.leggendariaScore.difficulty,
            col.srLeggendariaScore <- record.leggendariaScore.score,
            col.srLeggendariaPerfectGreatCount <- record.leggendariaScore.perfectGreatCount,
            col.srLeggendariaGreatCount <- record.leggendariaScore.greatCount,
            col.srLeggendariaMissCount <- record.leggendariaScore.missCount,
            col.srLeggendariaClearType <- record.leggendariaScore.clearType,
            col.srLeggendariaDJLevel <- record.leggendariaScore.djLevel
        ))
    }

    static func insertSong(database: Connection, song: IIDXSong) {
        let col = PlayDataDatabase.self
        _ = try? database.run(col.songTable.insert(
            col.songTitle <- song.title,
            col.songSPBeginnerNoteCount <- song.spNoteCount?.beginnerNoteCount,
            col.songSPNormalNoteCount <- song.spNoteCount?.normalNoteCount,
            col.songSPHyperNoteCount <- song.spNoteCount?.hyperNoteCount,
            col.songSPAnotherNoteCount <- song.spNoteCount?.anotherNoteCount,
            col.songSPLeggendariaNoteCount <- song.spNoteCount?.leggendariaNoteCount,
            col.songDPBeginnerNoteCount <- song.dpNoteCount?.beginnerNoteCount,
            col.songDPNormalNoteCount <- song.dpNoteCount?.normalNoteCount,
            col.songDPHyperNoteCount <- song.dpNoteCount?.hyperNoteCount,
            col.songDPAnotherNoteCount <- song.dpNoteCount?.anotherNoteCount,
            col.songDPLeggendariaNoteCount <- song.dpNoteCount?.leggendariaNoteCount,
            col.songTime <- song.time,
            col.songMovie <- song.movie,
            col.songLayer <- song.layer
        ))
    }

    static func insertTowerEntry(database: Connection, entry: IIDXTowerEntry) {
        let col = PlayDataDatabase.self
        _ = try? database.run(col.towerEntryTable.insert(
            col.tePlayDate <- entry.playDate.timeIntervalSince1970,
            col.teKeyCount <- entry.keyCount,
            col.teScratchCount <- entry.scratchCount
        ))
    }

    // MARK: Tower Import

    func importTowerCSV(_ keyedRows: [[String: String]]) {
        guard let database = try? PlayDataDatabase.shared.getWriteConnection() else { return }

        // Delete all existing tower entries
        _ = try? database.run(PlayDataDatabase.towerEntryTable.delete())

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"

        try? database.transaction {
            for keyedRow in keyedRows {
                guard let playDateString = keyedRow["プレー日"],
                      let playDate = dateFormatter.date(from: playDateString),
                      let keyCountString = keyedRow["鍵盤"],
                      let keyCount = Int(keyCountString),
                      let scratchCountString = keyedRow["スクラッチ"],
                      let scratchCount = Int(scratchCountString) else {
                    continue
                }
                let entry = IIDXTowerEntry(playDate: playDate, keyCount: keyCount, scratchCount: scratchCount)
                Self.insertTowerEntry(database: database, entry: entry)
            }
        }
    }

    // MARK: Migration

    func migrateImportGroup(
        _ importGroup: ImportGroup,
        songRecords: [IIDXSongRecord]
    ) {
        guard let database = try? PlayDataDatabase.shared.getWriteConnection() else { return }
        let col = PlayDataDatabase.self
        try? database.transaction {
            try database.run(col.importGroupTable.insert(
                col.igID <- importGroup.id,
                col.igImportDate <- importGroup.importDate.timeIntervalSince1970,
                col.igIIDXVersion <- importGroup.iidxVersion?.rawValue
            ))
            for record in songRecords {
                Self.insertSongRecord(database: database, record: record, importGroupID: importGroup.id)
            }
        }
    }

    func migrateSongs(_ songs: [IIDXSong]) {
        guard let database = try? PlayDataDatabase.shared.getWriteConnection() else { return }
        try? database.transaction {
            for song in songs {
                Self.insertSong(database: database, song: song)
            }
        }
    }

    func migrateTowerEntries(_ entries: [IIDXTowerEntry]) {
        guard let database = try? PlayDataDatabase.shared.getWriteConnection() else { return }
        try? database.transaction {
            for entry in entries {
                Self.insertTowerEntry(database: database, entry: entry)
            }
        }
    }

    // MARK: Delete Helpers

    func deleteImportGroup(id: String) {
        guard let database = try? PlayDataDatabase.shared.getWriteConnection() else { return }
        let col = PlayDataDatabase.self
        try? database.transaction {
            try database.run(col.songRecordTable.filter(col.srImportGroupID == id).delete())
            try database.run(col.importGroupTable.filter(col.igID == id).delete())
        }
    }

    func deleteAllScoreData() {
        guard let database = try? PlayDataDatabase.shared.getWriteConnection() else { return }
        let col = PlayDataDatabase.self
        try? database.transaction {
            try database.run(col.songRecordTable.delete())
            try database.run(col.importGroupTable.delete())
        }
    }

    func deleteAllSongs() {
        guard let database = try? PlayDataDatabase.shared.getWriteConnection() else { return }
        _ = try? database.run(PlayDataDatabase.songTable.delete())
    }

    func insertSongs(_ songs: [IIDXSong]) {
        guard let database = try? PlayDataDatabase.shared.getWriteConnection() else { return }
        try? database.transaction {
            for song in songs {
                Self.insertSong(database: database, song: song)
            }
        }
    }
}
