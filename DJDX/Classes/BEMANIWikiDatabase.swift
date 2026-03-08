//
//  BEMANIWikiDatabase.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2026/03/08.
//

import Foundation
import SQLite

final class BEMANIWikiDatabase: Sendable {

    static let shared = BEMANIWikiDatabase()

    let databasePath: String

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

    // MARK: - Initialization

    private init() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        databasePath = documentsURL.appendingPathComponent("ExD_BEMANIWiki.db").path
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

    private func createTablesIfNeeded() {
        do {
            let database = try Connection(databasePath)

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
        } catch {
            debugPrint("Failed to create BEMANIWiki tables: \(error)")
        }
    }
}
