import Foundation
import SQLite

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
final class PlaySessionsDatabase: Sendable {

    static let shared = PlaySessionsDatabase()

    let databasePath: String

    // MARK: - PlaySession Table

    static let sessionTable = Table("PlaySession")
    static let sID = SQLite.Expression<String>("id")
    static let sGame = SQLite.Expression<Int>("game")
    static let sStartDate = SQLite.Expression<Double>("startDate")
    static let sEndDate = SQLite.Expression<Double?>("endDate")
    static let sTitle = SQLite.Expression<String?>("title")
    static let sVenue = SQLite.Expression<String?>("venue")
    static let sWorkoutUUID = SQLite.Expression<String?>("workoutUUID")
    static let sLiveActivityID = SQLite.Expression<String?>("liveActivityID")
    static let sNotes = SQLite.Expression<String?>("notes")

    // MARK: - CapturedPlay Table

    static let playTable = Table("CapturedPlay")
    static let pID = SQLite.Expression<String>("id")
    static let pSessionID = SQLite.Expression<String>("sessionID")
    static let pCaptureDate = SQLite.Expression<Double>("captureDate")
    static let pSource = SQLite.Expression<String>("source")
    static let pRawImageFilename = SQLite.Expression<String>("rawImageFilename")
    static let pState = SQLite.Expression<String>("state")
    static let pSongTitle = SQLite.Expression<String?>("songTitle")
    static let pMatchedSongID = SQLite.Expression<Int64?>("matchedSongID")
    static let pLevel = SQLite.Expression<String>("level")
    static let pDifficulty = SQLite.Expression<Int>("difficulty")
    static let pPlayType = SQLite.Expression<String>("playType")
    static let pExScore = SQLite.Expression<Int>("exScore")
    static let pPerfectGreat = SQLite.Expression<Int>("perfectGreat")
    static let pGreat = SQLite.Expression<Int>("great")
    static let pMiss = SQLite.Expression<Int>("miss")
    static let pClearType = SQLite.Expression<String>("clearType")
    static let pDJLevel = SQLite.Expression<String>("djLevel")
    static let pOCRConfidence = SQLite.Expression<Double>("ocrConfidence")
    static let pParseError = SQLite.Expression<String?>("parseError")
    static let pProcessedAt = SQLite.Expression<Double?>("processedAt")
    static let pGaugeData = SQLite.Expression<Blob?>("gaugeData")

    // MARK: - Initialization

    init(fileName: String = "PlaySessions.db") {
        databasePath = SharedContainer.containerURL.appendingPathComponent(fileName).path
        createTablesIfNeeded()
    }

    func getReadConnection() throws -> Connection {
        try Connection(databasePath, readonly: true)
    }

    func getWriteConnection() throws -> Connection {
        try Connection(databasePath)
    }

    // swiftlint:disable:next function_body_length
    private func createTablesIfNeeded() {
        do {
            let database = try Connection(databasePath)

            try database.run(Self.sessionTable.create(ifNotExists: true) { table in
                table.column(Self.sID, primaryKey: true)
                table.column(Self.sGame, defaultValue: Game.iidxArcade.rawValue)
                table.column(Self.sStartDate)
                table.column(Self.sEndDate)
                table.column(Self.sTitle)
                table.column(Self.sVenue)
                table.column(Self.sWorkoutUUID)
                table.column(Self.sLiveActivityID)
                table.column(Self.sNotes)
            })

            try database.run(Self.playTable.create(ifNotExists: true) { table in
                table.column(Self.pID, primaryKey: true)
                table.column(Self.pSessionID)
                table.column(Self.pCaptureDate)
                table.column(Self.pSource, defaultValue: CapturedPlaySource.camera.rawValue)
                table.column(Self.pRawImageFilename, defaultValue: "")
                table.column(Self.pState, defaultValue: CapturedPlayState.pending.rawValue)
                table.column(Self.pSongTitle)
                table.column(Self.pMatchedSongID)
                table.column(Self.pLevel, defaultValue: "")
                table.column(Self.pDifficulty, defaultValue: 0)
                table.column(Self.pPlayType, defaultValue: IIDXPlayType.single.rawValue)
                table.column(Self.pExScore, defaultValue: 0)
                table.column(Self.pPerfectGreat, defaultValue: 0)
                table.column(Self.pGreat, defaultValue: 0)
                table.column(Self.pMiss, defaultValue: 0)
                table.column(Self.pClearType, defaultValue: IIDXClearType.noPlay.rawValue)
                table.column(Self.pDJLevel, defaultValue: IIDXDJLevel.none.rawValue)
                table.column(Self.pOCRConfidence, defaultValue: 0.0)
                table.column(Self.pParseError)
                table.column(Self.pProcessedAt)
                table.column(Self.pGaugeData)
            })

            try database.run(Self.playTable.createIndex(Self.pSessionID, ifNotExists: true))
            try database.run(Self.playTable.createIndex(Self.pState, ifNotExists: true))
            try database.run(Self.sessionTable.createIndex(Self.sStartDate, ifNotExists: true))
        } catch {
            debugPrint("Failed to create session tables: \(error)")
        }
    }

    // MARK: - Session CRUD

    func createSession(_ session: PlaySession) {
        guard let database = try? getWriteConnection() else { return }
        try? database.run(Self.sessionTable.insert(or: .replace,
            Self.sID <- session.id,
            Self.sGame <- session.game.rawValue,
            Self.sStartDate <- session.startDate.timeIntervalSince1970,
            Self.sEndDate <- session.endDate?.timeIntervalSince1970,
            Self.sTitle <- session.title,
            Self.sVenue <- session.venue,
            Self.sWorkoutUUID <- session.workoutUUID,
            Self.sLiveActivityID <- session.liveActivityID,
            Self.sNotes <- session.notes
        ))
    }

    func updateSession(_ session: PlaySession) {
        guard let database = try? getWriteConnection() else { return }
        try? database.run(Self.sessionTable.filter(Self.sID == session.id).update(
            Self.sEndDate <- session.endDate?.timeIntervalSince1970,
            Self.sTitle <- session.title,
            Self.sVenue <- session.venue,
            Self.sWorkoutUUID <- session.workoutUUID,
            Self.sLiveActivityID <- session.liveActivityID,
            Self.sNotes <- session.notes
        ))
    }

    func endSession(id: String, endDate: Date = .now) {
        guard let database = try? getWriteConnection() else { return }
        try? database.run(Self.sessionTable.filter(Self.sID == id).update(
            Self.sEndDate <- endDate.timeIntervalSince1970
        ))
    }

    func deleteSession(id: String) {
        for play in plays(forSession: id) {
            SessionImageStore.shared.delete(filename: play.rawImageFilename)
        }
        guard let database = try? getWriteConnection() else { return }
        try? database.run(Self.playTable.filter(Self.pSessionID == id).delete())
        try? database.run(Self.sessionTable.filter(Self.sID == id).delete())
    }

    func activeSession() -> PlaySession? {
        guard let database = try? getReadConnection() else { return nil }
        let query = Self.sessionTable.filter(Self.sEndDate == nil)
            .order(Self.sStartDate.desc).limit(1)
        guard let row = try? database.pluck(query) else { return nil }
        return Self.session(from: row)
    }

    func allSessions() -> [PlaySession] {
        guard let database = try? getReadConnection() else { return [] }
        let query = Self.sessionTable.order(Self.sStartDate.desc)
        guard let rows = try? database.prepare(query) else { return [] }
        return rows.map { Self.session(from: $0) }
    }

    func session(id: String) -> PlaySession? {
        guard let database = try? getReadConnection() else { return nil }
        guard let row = try? database.pluck(Self.sessionTable.filter(Self.sID == id)) else { return nil }
        return Self.session(from: row)
    }

    // MARK: - Play CRUD

    func insertPlay(_ play: CapturedPlay) {
        guard let database = try? getWriteConnection() else { return }
        try? database.run(Self.playTable.insert(or: .replace, setters(for: play)))
    }

    func updatePlay(_ play: CapturedPlay) {
        guard let database = try? getWriteConnection() else { return }
        try? database.run(Self.playTable.filter(Self.pID == play.id).update(setters(for: play)))
    }

    func updatePlayState(id: String, state: CapturedPlayState) {
        guard let database = try? getWriteConnection() else { return }
        try? database.run(Self.playTable.filter(Self.pID == id).update(Self.pState <- state.rawValue))
    }

    func plays(forSession sessionID: String) -> [CapturedPlay] {
        guard let database = try? getReadConnection() else { return [] }
        let query = Self.playTable.filter(Self.pSessionID == sessionID).order(Self.pCaptureDate.asc)
        guard let rows = try? database.prepare(query) else { return [] }
        return rows.map { Self.play(from: $0) }
    }

    func play(id: String) -> CapturedPlay? {
        guard let database = try? getReadConnection() else { return nil }
        guard let row = try? database.pluck(Self.playTable.filter(Self.pID == id)) else { return nil }
        return Self.play(from: row)
    }

    func incompletePlays() -> [CapturedPlay] {
        guard let database = try? getReadConnection() else { return [] }
        let query = Self.playTable.filter(
            Self.pState == CapturedPlayState.pending.rawValue ||
            Self.pState == CapturedPlayState.processing.rawValue
        ).order(Self.pCaptureDate.asc)
        guard let rows = try? database.prepare(query) else { return [] }
        return rows.map { Self.play(from: $0) }
    }

    func deletePlay(id: String) {
        if let play = play(id: id) {
            SessionImageStore.shared.delete(filename: play.rawImageFilename)
        }
        guard let database = try? getWriteConnection() else { return }
        try? database.run(Self.playTable.filter(Self.pID == id).delete())
    }

    // MARK: - Row mapping

    private func setters(for play: CapturedPlay) -> [Setter] {
        [
            Self.pID <- play.id,
            Self.pSessionID <- play.sessionID,
            Self.pCaptureDate <- play.captureDate.timeIntervalSince1970,
            Self.pSource <- play.source.rawValue,
            Self.pRawImageFilename <- play.rawImageFilename,
            Self.pState <- play.state.rawValue,
            Self.pSongTitle <- play.songTitle,
            Self.pMatchedSongID <- play.matchedSongID,
            Self.pLevel <- play.level.rawValue,
            Self.pDifficulty <- play.difficulty,
            Self.pPlayType <- play.playType.rawValue,
            Self.pExScore <- play.exScore,
            Self.pPerfectGreat <- play.perfectGreat,
            Self.pGreat <- play.great,
            Self.pMiss <- play.miss,
            Self.pClearType <- play.clearType,
            Self.pDJLevel <- play.djLevel,
            Self.pOCRConfidence <- play.ocrConfidence,
            Self.pParseError <- play.parseError,
            Self.pProcessedAt <- play.processedAt?.timeIntervalSince1970,
            Self.pGaugeData <- play.gaugeData.map { Blob(bytes: [UInt8]($0)) }
        ]
    }

    private static func session(from row: Row) -> PlaySession {
        PlaySession(
            id: row[sID],
            game: Game(rawValue: row[sGame]) ?? .iidxArcade,
            startDate: Date(timeIntervalSince1970: row[sStartDate]),
            endDate: row[sEndDate].map { Date(timeIntervalSince1970: $0) },
            title: row[sTitle],
            venue: row[sVenue],
            workoutUUID: row[sWorkoutUUID],
            liveActivityID: row[sLiveActivityID],
            notes: row[sNotes]
        )
    }

    private static func play(from row: Row) -> CapturedPlay {
        let play = CapturedPlay(
            id: row[pID],
            sessionID: row[pSessionID],
            captureDate: Date(timeIntervalSince1970: row[pCaptureDate]),
            source: CapturedPlaySource(rawValue: row[pSource]) ?? .camera,
            rawImageFilename: row[pRawImageFilename],
            state: CapturedPlayState(rawValue: row[pState]) ?? .pending
        )
        play.songTitle = row[pSongTitle]
        play.matchedSongID = row[pMatchedSongID]
        play.level = IIDXLevel(rawValue: row[pLevel]) ?? .unknown
        play.difficulty = row[pDifficulty]
        play.playType = IIDXPlayType(rawValue: row[pPlayType]) ?? .single
        play.exScore = row[pExScore]
        play.perfectGreat = row[pPerfectGreat]
        play.great = row[pGreat]
        play.miss = row[pMiss]
        play.clearType = row[pClearType]
        play.djLevel = row[pDJLevel]
        play.ocrConfidence = row[pOCRConfidence]
        play.parseError = row[pParseError]
        play.processedAt = row[pProcessedAt].map { Date(timeIntervalSince1970: $0) }
        play.gaugeData = row[pGaugeData].map { Data($0.bytes) }
        return play
    }
}
// swiftlint:enable file_length
