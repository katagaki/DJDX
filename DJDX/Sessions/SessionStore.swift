import Foundation
import Observation

@MainActor
@Observable
final class SessionStore {

    var activeSession: PlaySession?
    var plays: [CapturedPlay] = []
    var sessions: [PlaySession] = []

    private let database = PlaySessionsDatabase.shared

    func bootstrap() {
        activeSession = database.activeSession()
        loadSessions()
        if let activeSession {
            plays = database.plays(forSession: activeSession.id)
        }
    }

    func loadSessions() {
        sessions = database.allSessions()
    }

    func refreshPlays() {
        guard let activeSession else { plays = []; return }
        plays = database.plays(forSession: activeSession.id)
    }

    @discardableResult
    func startSession() -> PlaySession {
        let session = PlaySession(game: .iidxArcade)
        database.createSession(session)
        activeSession = session
        plays = []
        loadSessions()
        SessionLiveActivityController.shared.start(session)
        SessionWorkoutBridge.shared.startWorkout(session: session)
        NotificationCenter.default.post(name: .playSessionDidChange, object: session.id)
        return session
    }

    func endSession() {
        guard let activeSession else { return }
        database.endSession(id: activeSession.id)
        let endedID = activeSession.id
        SessionWorkoutBridge.shared.endWorkout(session: activeSession)
        self.activeSession = nil
        plays = []
        loadSessions()
        SessionLiveActivityController.shared.end()
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
        database.insertPlay(play)
        refreshPlays()
        SessionLiveActivityController.shared.refresh(sessionID: activeSession.id)
        Task { await SessionCaptureProcessor.shared.submit(id) }
    }

    func reprocess(_ play: CapturedPlay) {
        Task { await SessionCaptureProcessor.shared.reprocess(play.id) }
    }

    func saveCorrected(_ play: CapturedPlay) {
        play.state = .done
        database.updatePlay(play)
        refreshPlays()
        NotificationCenter.default.post(name: .capturedPlayDidChange, object: play.id)
    }

    func deletePlay(_ play: CapturedPlay) {
        database.deletePlay(id: play.id)
        refreshPlays()
    }

    func deleteSession(_ session: PlaySession) {
        database.deleteSession(id: session.id)
        if activeSession?.id == session.id { activeSession = nil; plays = [] }
        loadSessions()
    }

    func plays(for session: PlaySession) -> [CapturedPlay] {
        database.plays(forSession: session.id)
    }
}
