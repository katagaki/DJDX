import ActivityKit
import Foundation

@MainActor
final class IIDXSessionLiveActivityController {
    static let shared = IIDXSessionLiveActivityController()

    private var activity: Activity<SessionActivityAttributes>?
    private var sessionID: String?
    private let database = IIDXPlaySessionsDatabase.shared
    private var latestHeartRate: Int?
    private var latestActiveCalories: Int?
    private var isPaused: Bool = false
    private var pausedElapsed: TimeInterval?
    private var runningStart: Date?

    func start(_ session: IIDXPlaySession) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        end()
        resetTransientState()
        let attributes = SessionActivityAttributes(
            sessionID: session.id,
            sessionStart: session.startDate,
            gameShortName: session.game.shortName,
            gameIconAssetName: "GameIconIIDX"
        )
        let content = ActivityContent(state: contentState(for: session.id), staleDate: nil)
        guard let activity = try? Activity.request(attributes: attributes, content: content) else {
            self.activity = nil
            sessionID = nil
            return
        }
        self.activity = activity
        sessionID = session.id
    }

    func reconcile() {
        let activeSession = database.activeSession()
        var adopted: Activity<SessionActivityAttributes>?
        for existing in Activity<SessionActivityAttributes>.activities {
            if let activeSession,
               existing.attributes.sessionID == activeSession.id,
               existing.activityState == .active {
                adopted = existing
            } else {
                endActivity(existing, sessionID: existing.attributes.sessionID)
            }
        }

        guard let activeSession else {
            activity = nil
            sessionID = nil
            return
        }

        if let adopted {
            activity = adopted
            sessionID = activeSession.id
            refresh(sessionID: activeSession.id)
        } else {
            start(activeSession)
        }
    }

    private func endActivity(_ activity: Activity<SessionActivityAttributes>, sessionID: String) {
        let content = ActivityContent(state: contentState(for: sessionID), staleDate: nil)
        nonisolated(unsafe) let target = activity
        Task { await target.end(content, dismissalPolicy: .immediate) }
    }

    func refresh(sessionID: String) {
        guard sessionID == self.sessionID, let activity else { return }
        let content = ActivityContent(state: contentState(for: sessionID), staleDate: nil)
        nonisolated(unsafe) let target = activity
        Task { await target.update(content) }
    }

    func pushSessionInfoToWatch(sessionID: String) {
        let state = contentState(for: sessionID)
        IIDXSessionWorkoutBridge.shared.pushSessionInfo(
            sessionID: sessionID,
            playCount: state.playCount,
            lastSongTitle: state.lastSongTitle,
            lastDJLevel: state.lastDJLevel,
            lastClearType: state.lastClearType,
            lastScore: state.lastScore,
            lastResultSummary: state.lastResultSummary
        )
    }

    func updateMetrics(sessionID: String, heartRate: Int?, activeCalories: Int?) {
        guard sessionID == self.sessionID, let activity else { return }
        latestHeartRate = heartRate
        latestActiveCalories = activeCalories
        let content = ActivityContent(state: contentState(for: sessionID), staleDate: nil)
        nonisolated(unsafe) let target = activity
        Task { await target.update(content) }
    }

    func updatePauseState(sessionID: String, isPaused: Bool, pausedElapsed: TimeInterval?, runningStart: Date?) {
        guard sessionID == self.sessionID, let activity else { return }
        self.isPaused = isPaused
        self.pausedElapsed = pausedElapsed
        self.runningStart = runningStart
        let content = ActivityContent(state: contentState(for: sessionID), staleDate: nil)
        nonisolated(unsafe) let target = activity
        Task { await target.update(content) }
    }

    private func resetTransientState() {
        latestHeartRate = nil
        latestActiveCalories = nil
        isPaused = false
        pausedElapsed = nil
        runningStart = nil
    }

    func end() {
        guard let activity, let sessionID else { return }
        let content = ActivityContent(state: contentState(for: sessionID), staleDate: nil)
        nonisolated(unsafe) let target = activity
        Task { await target.end(content, dismissalPolicy: .immediate) }
        self.activity = nil
        self.sessionID = nil
    }

    private func contentState(for sessionID: String) -> SessionActivityAttributes.ContentState {
        let plays = database.plays(forSession: sessionID)
        let last = plays.last
        let isProcessing = plays.contains { !$0.state.isTerminal }
        return SessionActivityAttributes.ContentState(
            playCount: plays.count,
            lastSongTitle: last?.songTitle,
            lastDJLevel: last.flatMap(Self.djLevel),
            lastClearType: last.flatMap(Self.clearType),
            lastScore: last.flatMap(Self.score),
            lastResultSummary: last.flatMap(Self.summary),
            bestThisSession: Self.best(plays),
            heartRate: latestHeartRate,
            activeCalories: latestActiveCalories,
            isPaused: isPaused,
            pausedElapsed: pausedElapsed,
            runningStart: runningStart,
            isProcessing: isProcessing
        )
    }

    private static func djLevel(_ play: IIDXCapturedPlay) -> String? {
        play.djLevel != IIDXDJLevel.none.rawValue ? play.djLevel : nil
    }

    private static func clearType(_ play: IIDXCapturedPlay) -> String? {
        play.clearType != IIDXClearType.noPlay.rawValue ? play.clearType : nil
    }

    private static func score(_ play: IIDXCapturedPlay) -> Int? {
        play.exScore > 0 ? play.exScore : nil
    }

    private static func summary(_ play: IIDXCapturedPlay) -> String? {
        var parts: [String] = []
        if play.clearType != IIDXClearType.noPlay.rawValue {
            parts.append(IIDXClearType.abbreviation(for: play.clearType))
        }
        if play.djLevel != IIDXDJLevel.none.rawValue {
            parts.append(play.djLevel)
        }
        if play.exScore > 0 {
            parts.append("\(play.exScore)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func best(_ plays: [IIDXCapturedPlay]) -> String? {
        let levels = plays
            .map { IIDXDJLevel(rawValue: $0.djLevel) ?? .none }
            .filter { $0 != .none }
        guard let best = levels.max(by: { $0 < $1 }) else { return nil }
        return best.rawValue
    }
}
