//
//  BM2DXDatabase.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2026/03/08.
//

import Foundation
import SQLite

final class BM2DXDatabase: Sendable {

    static let shared = BM2DXDatabase()

    let databasePath: String

    // MARK: - NotesRadar Table

    static let notesRadarTable = Table("NotesRadar")
    static let nrID = SQLite.Expression<Int64>("id")
    static let nrTitle = SQLite.Expression<String>("title")
    static let nrPlayType = SQLite.Expression<String>("playType")
    static let nrDifficulty = SQLite.Expression<Int>("difficulty")
    static let nrNoteCount = SQLite.Expression<Int>("noteCount")
    static let nrNotes = SQLite.Expression<Double>("notes")
    static let nrChord = SQLite.Expression<Double>("chord")
    static let nrPeak = SQLite.Expression<Double>("peak")
    static let nrCharge = SQLite.Expression<Double>("charge")
    static let nrScratch = SQLite.Expression<Double>("scratch")
    static let nrSoflan = SQLite.Expression<Double>("soflan")

    // MARK: - Initialization

    private init() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        databasePath = documentsURL.appendingPathComponent("ExD_BM2DX.db").path
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

            try database.run(Self.notesRadarTable.create(ifNotExists: true) { table in
                table.column(Self.nrID, primaryKey: .autoincrement)
                table.column(Self.nrTitle, defaultValue: "")
                table.column(Self.nrPlayType, defaultValue: "SP")
                table.column(Self.nrDifficulty, defaultValue: 0)
                table.column(Self.nrNoteCount, defaultValue: 0)
                table.column(Self.nrNotes, defaultValue: 0.0)
                table.column(Self.nrChord, defaultValue: 0.0)
                table.column(Self.nrPeak, defaultValue: 0.0)
                table.column(Self.nrCharge, defaultValue: 0.0)
                table.column(Self.nrScratch, defaultValue: 0.0)
                table.column(Self.nrSoflan, defaultValue: 0.0)
            })

            try database.run(Self.notesRadarTable.createIndex(
                Self.nrTitle, Self.nrPlayType, Self.nrDifficulty,
                unique: true,
                ifNotExists: true
            ))
        } catch {
            debugPrint("Failed to create BM2DX tables: \(error)")
        }
    }
}
