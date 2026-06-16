import Foundation
import Observation

@MainActor
@Observable
final class SessionStore {

    var activeSession: PlaySession?
    var plays: [CapturedPlay] = []
    var sessions: [PlaySession] = []

    private let db = PlaySessionsDatabase.shared

    func bootstrap() {
        activeSession = db.activeSession()
        loadSessions()
        if let activeSession {
            plays = db.plays(forSession: activeSession.id)
        }
    }

    func loadSessions() {
        sessions = db.allSessions()
    }

    func refreshPlays() {
        guard let activeSession else { plays = []; return }
        plays = db.plays(forSession: activeSession.id)
    }

    @discardableResult
    func startSession() -> PlaySession {
        let session = PlaySession(game: .iidxArcade)
        db.createSession(session)
        activeSession = session
        plays = []
        loadSessions()
        NotificationCenter.default.post(name: .playSessionDidChange, object: session.id)
        return session
    }

    func endSession() {
        guard let activeSession else { return }
        db.endSession(id: activeSession.id)
        let endedID = activeSession.id
        self.activeSession = nil
        plays = []
        loadSessions()
        NotificationCenter.default.post(name: .playSessionDidChange, object: endedID)
    }

    func capture(_ imageData: Data, source: CapturedPlaySource) {
        guard let activeSession else { return }
        let id = UUID().uuidString
        let filename = SessionImageStore.shared.write(imageData, id: id)
        let play = CapturedPlay(
            id: id,
            sessionID: activeSession.id,
            source: source,
            rawImageFilename: filename,
            state: .pending
        )
        db.insertPlay(play)
        refreshPlays()
        Task { await SessionCaptureProcessor.shared.submit(id) }
    }

    func reprocess(_ play: CapturedPlay) {
        Task { await SessionCaptureProcessor.shared.reprocess(play.id) }
    }

    func saveCorrected(_ play: CapturedPlay) {
        play.state = .done
        db.updatePlay(play)
        refreshPlays()
        NotificationCenter.default.post(name: .capturedPlayDidChange, object: play.id)
    }

    func deletePlay(_ play: CapturedPlay) {
        db.deletePlay(id: play.id)
        refreshPlays()
    }

    func deleteSession(_ session: PlaySession) {
        db.deleteSession(id: session.id)
        if activeSession?.id == session.id { activeSession = nil; plays = [] }
        loadSessions()
    }

    func plays(for session: PlaySession) -> [CapturedPlay] {
        db.plays(forSession: session.id)
    }
}
