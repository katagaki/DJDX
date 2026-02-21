//
//  PlayDataDatabase.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2026/02/21.
//

import Foundation
import SQLite

final class PlayDataDatabase: Sendable {

    static let shared = PlayDataDatabase()

    let databasePath: String

    // MARK: - ImportGroup Table

    static let importGroupTable = Table("ImportGroup")
    static let igID = SQLite.Expression<String>("id")
    static let igImportDate = SQLite.Expression<Double>("importDate")
    static let igIIDXVersion = SQLite.Expression<Int?>("iidxVersion")

    // MARK: - IIDXSongRecord Table

    static let songRecordTable = Table("IIDXSongRecord")
    static let srID = SQLite.Expression<Int64>("id")
    static let srImportGroupID = SQLite.Expression<String>("importGroupID")
    static let srVersion = SQLite.Expression<String>("version")
    static let srTitle = SQLite.Expression<String>("title")
    static let srGenre = SQLite.Expression<String>("genre")
    static let srArtist = SQLite.Expression<String>("artist")
    static let srPlayCount = SQLite.Expression<Int>("playCount")
    static let srPlayType = SQLite.Expression<String>("playType")
    static let srLastPlayDate = SQLite.Expression<Double>("lastPlayDate")

    // Beginner score columns
    static let srBeginnerLevel = SQLite.Expression<String>("beginnerLevel")
    static let srBeginnerDifficulty = SQLite.Expression<Int>("beginnerDifficulty")
    static let srBeginnerScore = SQLite.Expression<Int>("beginnerScore")
    static let srBeginnerPerfectGreatCount = SQLite.Expression<Int>("beginnerPerfectGreatCount")
    static let srBeginnerGreatCount = SQLite.Expression<Int>("beginnerGreatCount")
    static let srBeginnerMissCount = SQLite.Expression<Int>("beginnerMissCount")
    static let srBeginnerClearType = SQLite.Expression<String>("beginnerClearType")
    static let srBeginnerDJLevel = SQLite.Expression<String>("beginnerDJLevel")

    // Normal score columns
    static let srNormalLevel = SQLite.Expression<String>("normalLevel")
    static let srNormalDifficulty = SQLite.Expression<Int>("normalDifficulty")
    static let srNormalScore = SQLite.Expression<Int>("normalScore")
    static let srNormalPerfectGreatCount = SQLite.Expression<Int>("normalPerfectGreatCount")
    static let srNormalGreatCount = SQLite.Expression<Int>("normalGreatCount")
    static let srNormalMissCount = SQLite.Expression<Int>("normalMissCount")
    static let srNormalClearType = SQLite.Expression<String>("normalClearType")
    static let srNormalDJLevel = SQLite.Expression<String>("normalDJLevel")

    // Hyper score columns
    static let srHyperLevel = SQLite.Expression<String>("hyperLevel")
    static let srHyperDifficulty = SQLite.Expression<Int>("hyperDifficulty")
    static let srHyperScore = SQLite.Expression<Int>("hyperScore")
    static let srHyperPerfectGreatCount = SQLite.Expression<Int>("hyperPerfectGreatCount")
    static let srHyperGreatCount = SQLite.Expression<Int>("hyperGreatCount")
    static let srHyperMissCount = SQLite.Expression<Int>("hyperMissCount")
    static let srHyperClearType = SQLite.Expression<String>("hyperClearType")
    static let srHyperDJLevel = SQLite.Expression<String>("hyperDJLevel")

    // Another score columns
    static let srAnotherLevel = SQLite.Expression<String>("anotherLevel")
    static let srAnotherDifficulty = SQLite.Expression<Int>("anotherDifficulty")
    static let srAnotherScore = SQLite.Expression<Int>("anotherScore")
    static let srAnotherPerfectGreatCount = SQLite.Expression<Int>("anotherPerfectGreatCount")
    static let srAnotherGreatCount = SQLite.Expression<Int>("anotherGreatCount")
    static let srAnotherMissCount = SQLite.Expression<Int>("anotherMissCount")
    static let srAnotherClearType = SQLite.Expression<String>("anotherClearType")
    static let srAnotherDJLevel = SQLite.Expression<String>("anotherDJLevel")

    // Leggendaria score columns
    static let srLeggendariaLevel = SQLite.Expression<String>("leggendariaLevel")
    static let srLeggendariaDifficulty = SQLite.Expression<Int>("leggendariaDifficulty")
    static let srLeggendariaScore = SQLite.Expression<Int>("leggendariaScore")
    static let srLeggendariaPerfectGreatCount = SQLite.Expression<Int>("leggendariaPerfectGreatCount")
    static let srLeggendariaGreatCount = SQLite.Expression<Int>("leggendariaGreatCount")
    static let srLeggendariaMissCount = SQLite.Expression<Int>("leggendariaMissCount")
    static let srLeggendariaClearType = SQLite.Expression<String>("leggendariaClearType")
    static let srLeggendariaDJLevel = SQLite.Expression<String>("leggendariaDJLevel")

    // MARK: - IIDXSong Table

    static let songTable = Table("IIDXSong")
    static let songID = SQLite.Expression<Int64>("id")
    static let songTitle = SQLite.Expression<String>("title")
    static let songSPBeginnerNoteCount = SQLite.Expression<Int?>("spBeginnerNoteCount")
    static let songSPNormalNoteCount = SQLite.Expression<Int?>("spNormalNoteCount")
    static let songSPHyperNoteCount = SQLite.Expression<Int?>("spHyperNoteCount")
    static let songSPAnotherNoteCount = SQLite.Expression<Int?>("spAnotherNoteCount")
    static let songSPLeggendariaNoteCount = SQLite.Expression<Int?>("spLeggendariaNoteCount")
    static let songDPBeginnerNoteCount = SQLite.Expression<Int?>("dpBeginnerNoteCount")
    static let songDPNormalNoteCount = SQLite.Expression<Int?>("dpNormalNoteCount")
    static let songDPHyperNoteCount = SQLite.Expression<Int?>("dpHyperNoteCount")
    static let songDPAnotherNoteCount = SQLite.Expression<Int?>("dpAnotherNoteCount")
    static let songDPLeggendariaNoteCount = SQLite.Expression<Int?>("dpLeggendariaNoteCount")
    static let songTime = SQLite.Expression<String>("time")
    static let songMovie = SQLite.Expression<String>("movie")
    static let songLayer = SQLite.Expression<String>("layer")

    // MARK: - IIDXTowerEntry Table

    static let towerEntryTable = Table("IIDXTowerEntry")
    static let teID = SQLite.Expression<Int64>("id")
    static let tePlayDate = SQLite.Expression<Double>("playDate")
    static let teKeyCount = SQLite.Expression<Int>("keyCount")
    static let teScratchCount = SQLite.Expression<Int>("scratchCount")

    // MARK: - Initialization

    private init() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        databasePath = documentsURL.appendingPathComponent("PlayData.db").path
        createTablesIfNeeded()
    }

    // MARK: - Connection

    func getReadConnection() throws -> Connection {
        let connection = try Connection(databasePath, readonly: true)
        return connection
    }

    func getWriteConnection() throws -> Connection {
        let connection = try Connection(databasePath)
        return connection
    }

    // MARK: - Table Creation

    // swiftlint:disable function_body_length
    private func createTablesIfNeeded() {
        do {
            let database = try Connection(databasePath)

            try database.run(Self.importGroupTable.create(ifNotExists: true) { table in
                table.column(Self.igID, primaryKey: true)
                table.column(Self.igImportDate)
                table.column(Self.igIIDXVersion)
            })

            try database.run(Self.songRecordTable.create(ifNotExists: true) { table in
                table.column(Self.srID, primaryKey: .autoincrement)
                table.column(Self.srImportGroupID)
                table.column(Self.srVersion, defaultValue: "")
                table.column(Self.srTitle, defaultValue: "")
                table.column(Self.srGenre, defaultValue: "")
                table.column(Self.srArtist, defaultValue: "")
                table.column(Self.srPlayCount, defaultValue: 0)
                table.column(Self.srPlayType, defaultValue: "single")
                table.column(Self.srLastPlayDate, defaultValue: Date.distantPast.timeIntervalSince1970)
                // Beginner
                table.column(Self.srBeginnerLevel, defaultValue: "")
                table.column(Self.srBeginnerDifficulty, defaultValue: 0)
                table.column(Self.srBeginnerScore, defaultValue: 0)
                table.column(Self.srBeginnerPerfectGreatCount, defaultValue: 0)
                table.column(Self.srBeginnerGreatCount, defaultValue: 0)
                table.column(Self.srBeginnerMissCount, defaultValue: 0)
                table.column(Self.srBeginnerClearType, defaultValue: "NO PLAY")
                table.column(Self.srBeginnerDJLevel, defaultValue: "---")
                // Normal
                table.column(Self.srNormalLevel, defaultValue: "")
                table.column(Self.srNormalDifficulty, defaultValue: 0)
                table.column(Self.srNormalScore, defaultValue: 0)
                table.column(Self.srNormalPerfectGreatCount, defaultValue: 0)
                table.column(Self.srNormalGreatCount, defaultValue: 0)
                table.column(Self.srNormalMissCount, defaultValue: 0)
                table.column(Self.srNormalClearType, defaultValue: "NO PLAY")
                table.column(Self.srNormalDJLevel, defaultValue: "---")
                // Hyper
                table.column(Self.srHyperLevel, defaultValue: "")
                table.column(Self.srHyperDifficulty, defaultValue: 0)
                table.column(Self.srHyperScore, defaultValue: 0)
                table.column(Self.srHyperPerfectGreatCount, defaultValue: 0)
                table.column(Self.srHyperGreatCount, defaultValue: 0)
                table.column(Self.srHyperMissCount, defaultValue: 0)
                table.column(Self.srHyperClearType, defaultValue: "NO PLAY")
                table.column(Self.srHyperDJLevel, defaultValue: "---")
                // Another
                table.column(Self.srAnotherLevel, defaultValue: "")
                table.column(Self.srAnotherDifficulty, defaultValue: 0)
                table.column(Self.srAnotherScore, defaultValue: 0)
                table.column(Self.srAnotherPerfectGreatCount, defaultValue: 0)
                table.column(Self.srAnotherGreatCount, defaultValue: 0)
                table.column(Self.srAnotherMissCount, defaultValue: 0)
                table.column(Self.srAnotherClearType, defaultValue: "NO PLAY")
                table.column(Self.srAnotherDJLevel, defaultValue: "---")
                // Leggendaria
                table.column(Self.srLeggendariaLevel, defaultValue: "")
                table.column(Self.srLeggendariaDifficulty, defaultValue: 0)
                table.column(Self.srLeggendariaScore, defaultValue: 0)
                table.column(Self.srLeggendariaPerfectGreatCount, defaultValue: 0)
                table.column(Self.srLeggendariaGreatCount, defaultValue: 0)
                table.column(Self.srLeggendariaMissCount, defaultValue: 0)
                table.column(Self.srLeggendariaClearType, defaultValue: "NO PLAY")
                table.column(Self.srLeggendariaDJLevel, defaultValue: "---")
            })

            try database.run(Self.songTable.create(ifNotExists: true) { table in
                table.column(Self.songID, primaryKey: .autoincrement)
                table.column(Self.songTitle, defaultValue: "")
                table.column(Self.songSPBeginnerNoteCount)
                table.column(Self.songSPNormalNoteCount)
                table.column(Self.songSPHyperNoteCount)
                table.column(Self.songSPAnotherNoteCount)
                table.column(Self.songSPLeggendariaNoteCount)
                table.column(Self.songDPBeginnerNoteCount)
                table.column(Self.songDPNormalNoteCount)
                table.column(Self.songDPHyperNoteCount)
                table.column(Self.songDPAnotherNoteCount)
                table.column(Self.songDPLeggendariaNoteCount)
                table.column(Self.songTime, defaultValue: "")
                table.column(Self.songMovie, defaultValue: "")
                table.column(Self.songLayer, defaultValue: "")
            })

            try database.run(Self.towerEntryTable.create(ifNotExists: true) { table in
                table.column(Self.teID, primaryKey: .autoincrement)
                table.column(Self.tePlayDate)
                table.column(Self.teKeyCount, defaultValue: 0)
                table.column(Self.teScratchCount, defaultValue: 0)
            })
            // MARK: Indexes
            try database.run(Self.songRecordTable.createIndex(
                Self.srImportGroupID, Self.srPlayType,
                ifNotExists: true
            ))
            try database.run(Self.importGroupTable.createIndex(
                Self.igIIDXVersion,
                ifNotExists: true
            ))
        } catch {
            debugPrint("Failed to create tables: \(error)")
        }
    }
    // swiftlint:enable function_body_length
}
