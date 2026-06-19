import Foundation
import Observation

@MainActor
@Observable
final class SessionStore {

    var activeSession: IIDXPlaySession?
    var plays: [IIDXCapturedPlay] = []
    var sessions: [IIDXPlaySession] = []
    var pendingCaptureRequest: Bool = false

    private let database = IIDXPlaySessionsDatabase.shared

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
    func startSession() -> IIDXPlaySession {
        let session = IIDXPlaySession(game: .iidxArcade)
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

    func capture(_ imageData: Data, source: IIDXCapturedPlaySource) {
        guard let activeSession else { return }
        let id = UUID().uuidString
        let captureDate = Date()
        let filename = SessionImageStore.shared.write(imageData, id: id)
        let play = IIDXCapturedPlay(
            id: id,
            sessionID: activeSession.id,
            captureDate: captureDate,
            source: source,
            rawImageFilename: filename,
            state: .pending
        )
        database.insertPlay(play)
        refreshPlays()
        SessionLiveActivityController.shared.refresh(sessionID: activeSession.id)
        Task { await SessionCaptureProcessor.shared.submit(id) }
        snapshotHeartRate(playID: id, at: captureDate)
    }

    func requestCapture() {
        pendingCaptureRequest = true
    }

    private func snapshotHeartRate(playID: String, at date: Date) {
        Task {
            guard let range = await SessionWorkoutBridge.shared.heartRateRange(ending: date) else { return }
            database.updatePlayHeartRate(id: playID, min: range.min, max: range.max)
            refreshPlays()
            NotificationCenter.default.post(name: .capturedPlayDidChange, object: playID)
        }
    }

    func reprocess(_ play: IIDXCapturedPlay) {
        Task { await SessionCaptureProcessor.shared.reprocess(play.id) }
    }

    func saveCorrected(_ play: IIDXCapturedPlay) {
        play.state = .done
        database.updatePlay(play)
        refreshPlays()
        NotificationCenter.default.post(name: .capturedPlayDidChange, object: play.id)
    }

    func deletePlay(_ play: IIDXCapturedPlay) {
        database.deletePlay(id: play.id)
        refreshPlays()
    }

    func deleteSession(_ session: IIDXPlaySession) {
        database.deleteSession(id: session.id)
        if activeSession?.id == session.id { activeSession = nil; plays = [] }
        loadSessions()
    }

    func plays(for session: IIDXPlaySession) -> [IIDXCapturedPlay] {
        database.plays(forSession: session.id)
    }
}
