import Foundation

/// Orders asynchronous replies and remembers failed starts until an explicit new attempt arrives.
nonisolated struct WatchSessionHandshake {
    enum Decision: Equatable {
        case stale, inactive, failed, start
    }

    private(set) var requestID: UUID?
    private(set) var acceptedStartKey: String?
    private var failedStartKey: String?

    mutating func beginRequest() -> UUID {
        let id = UUID()
        requestID = id
        return id
    }

    mutating func accept(requestID: UUID, sessionID: String?, attemptID: String?) -> Decision {
        guard self.requestID == requestID else { return .stale }
        self.requestID = nil
        guard let sessionID, !sessionID.isEmpty else {
            acceptedStartKey = nil
            return .inactive
        }
        let key = sessionID + ":" + (attemptID ?? sessionID)
        acceptedStartKey = key
        return key == failedStartKey ? .failed : .start
    }

    mutating func failStart() {
        failedStartKey = acceptedStartKey
    }

    mutating func cancelRequest(_ id: UUID) {
        if requestID == id { requestID = nil }
    }

    mutating func invalidate() {
        requestID = nil
        acceptedStartKey = nil
    }
}

/// Extract value types before crossing from WatchConnectivity's callback queue to the main actor.
nonisolated struct WatchSessionSnapshot: Sendable {
    let sessionID: String?
    let attemptID: String?
    let paused: Bool
    let clock: SessionElapsedClock?

    init?(reply: [String: Any]) {
        guard let active = reply["active"] as? Bool else { return nil }
        if active {
            guard let id = reply["sessionID"] as? String, !id.isEmpty else { return nil }
            sessionID = id
        } else {
            sessionID = nil
        }
        attemptID = reply["startAttemptID"] as? String
        clock = SessionElapsedClock(data: reply["timer"] as? Data)
            ?? (reply["start"] as? Double).map { SessionElapsedClock(start: Date(timeIntervalSince1970: $0)) }
        paused = clock?.isPaused ?? (reply["paused"] as? Bool ?? false)
    }
}
