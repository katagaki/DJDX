import Foundation
import Observation

@MainActor
@Observable
final class IIDXSessionStore {

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
    func startSession(id: String? = nil) -> IIDXPlaySession {
        let session = IIDXPlaySession(id: id ?? UUID().uuidString, game: .iidxArcade)
        database.createSession(session)
        activeSession = session
        plays = []
        loadSessions()
        IIDXSessionLiveActivityController.shared.start(session)
        IIDXSessionWorkoutBridge.shared.startWorkout(session: session)
        IIDXSessionLiveActivityController.shared.pushSessionInfoToWatch(sessionID: session.id)
        NotificationCenter.default.post(name: .playSessionDidChange, object: session.id)
        return session
    }

    func endSession() {
        guard let activeSession else { return }
        guard database.endSession(id: activeSession.id) else { return }
        let endedID = activeSession.id
        IIDXSessionWorkoutBridge.shared.endWorkout(session: activeSession)
        self.activeSession = nil
        plays = []
        loadSessions()
        IIDXSessionLiveActivityController.shared.end()
        NotificationCenter.default.post(name: .playSessionDidChange, object: endedID)
    }

    func capture(_ imageData: Data, source: IIDXCapturedPlaySource, staged: [DetectedRegion] = []) {
        guard let activeSession else { return }
        let id = UUID().uuidString
        let captureDate = Date()
        let filename = IIDXSessionImageStore.shared.write(imageData, id: id)
        IIDXLiveResultAccumulator.shared.stage(staged, for: id)
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
        IIDXSessionLiveActivityController.shared.refresh(sessionID: activeSession.id)
        IIDXSessionLiveActivityController.shared.pushSessionInfoToWatch(sessionID: activeSession.id)
        Task { await IIDXSessionCaptureProcessor.shared.submit(id) }
        snapshotHeartRate(playID: id, at: captureDate)
    }

    func requestCapture() {
        pendingCaptureRequest = true
    }

    private func snapshotHeartRate(playID: String, at date: Date) {
        Task {
            guard let range = await IIDXSessionWorkoutBridge.shared.heartRateRange(ending: date) else { return }
            database.updatePlayHeartRate(id: playID, min: range.min, max: range.max)
            refreshPlays()
            NotificationCenter.default.post(name: .capturedPlayDidChange, object: playID)
        }
    }

    func reprocess(_ play: IIDXCapturedPlay) {
        Task { await IIDXSessionCaptureProcessor.shared.reprocess(play.id) }
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

    func play(id: String) -> IIDXCapturedPlay? {
        database.play(id: id)
    }
}
