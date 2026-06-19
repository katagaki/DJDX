import ActivityKit
import Foundation

@MainActor
final class IIDXSessionLiveActivityController {
    static let shared = IIDXSessionLiveActivityController()

    private var activity: Activity<SessionActivityAttributes>?
    private var sessionID: String?
    private let database = IIDXPlaySessionsDatabase.shared

    func start(_ session: IIDXPlaySession) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        end()
        let attributes = SessionActivityAttributes(
            sessionID: session.id,
            sessionStart: session.startDate,
            gameShortName: session.game.shortName,
            gameIconAssetName: "GameIconIIDX"
        )
        let content = ActivityContent(state: contentState(for: session.id), staleDate: nil)
        activity = try? Activity.request(attributes: attributes, content: content)
        sessionID = session.id
    }

    // Cold-launch recovery: if a session is still active, adopt a Live Activity
    // that the system kept alive, or start a fresh one if it was removed (e.g.
    // force quit). Any activity for an already-ended session is cleaned up.
    func reconcile() {
        let activeSession = database.activeSession()
        var adopted: Activity<SessionActivityAttributes>?
        for existing in Activity<SessionActivityAttributes>.activities {
            if let activeSession, existing.attributes.sessionID == activeSession.id {
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
        } else if activity == nil {
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

    func updateMetrics(sessionID: String, heartRate: Int?, activeCalories: Int?) {
        guard sessionID == self.sessionID, let activity else { return }
        var state = contentState(for: sessionID)
        state.heartRate = heartRate
        state.activeCalories = activeCalories
        let content = ActivityContent(state: state, staleDate: nil)
        nonisolated(unsafe) let target = activity
        Task { await target.update(content) }
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
            lastResultSummary: last.flatMap(Self.summary),
            bestThisSession: Self.best(plays),
            heartRate: nil,
            activeCalories: nil,
            isProcessing: isProcessing
        )
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
