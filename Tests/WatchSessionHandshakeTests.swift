import Foundation

// Run: swiftc 'DJDX CHARGE/WatchSessionHandshake.swift' Tests/WatchSessionHandshakeTests.swift \
//      -o /tmp/djdx-watch-sync-tests && /tmp/djdx-watch-sync-tests
@main
struct WatchSessionHandshakeTests {
    static func main() {
        var handshake = WatchSessionHandshake()
        let oldReply = handshake.beginRequest()
        let newReply = handshake.beginRequest()
        expect(handshake.accept(requestID: oldReply, sessionID: "ended", attemptID: "1") == .stale,
               "An older response must not replace a newer request")
        expect(handshake.accept(requestID: newReply, sessionID: "active", attemptID: "1") == .start,
               "The current request can start a session")
        expect(handshake.accept(requestID: newReply, sessionID: "active", attemptID: "1") == .stale,
               "Duplicate responses are ignored")
        handshake.failStart()
        let duplicate = handshake.beginRequest()
        expect(handshake.accept(requestID: duplicate, sessionID: "active", attemptID: "1") == .failed,
               "Repeated hints must not repeatedly start a failed workout")
        let retry = handshake.beginRequest()
        expect(handshake.accept(requestID: retry, sessionID: "active", attemptID: "2") == .start,
               "An explicit retry permits the same session to try again")
        let cancelled = handshake.beginRequest()
        handshake.invalidate()
        expect(handshake.accept(requestID: cancelled, sessionID: "active", attemptID: "2") == .stale,
               "Stopping during a handshake invalidates its late reply")
        let inactive = handshake.beginRequest()
        expect(handshake.accept(requestID: inactive, sessionID: nil, attemptID: nil) == .inactive,
               "No active phone session means a provisional workout must stop")
        let timedOut = handshake.beginRequest()
        handshake.cancelRequest(timedOut)
        let replacement = handshake.beginRequest()
        handshake.cancelRequest(timedOut)
        expect(handshake.accept(requestID: replacement, sessionID: "next", attemptID: nil) == .start,
               "An old timeout must not cancel a replacement request")
        handshake.failStart()
        let differentSession = handshake.beginRequest()
        expect(handshake.accept(requestID: differentSession, sessionID: "different", attemptID: nil) == .start,
               "Failure of one session must not block another")
        expect(WatchSessionSnapshot(reply: [:]) == nil,
               "A malformed reply must not be interpreted as an ended session")
        expect(WatchSessionSnapshot(reply: ["active": true]) == nil,
               "An active reply requires a session identifier")
        let snapshot = WatchSessionSnapshot(reply: ["active": true, "sessionID": "next", "paused": true])
        expect(snapshot?.sessionID == "next" && snapshot?.paused == true,
               "The snapshot preserves the phone's current session and pause state")
        print("Passed 12 Watch session handshake regression checks")
    }

    private static func expect(_ condition: Bool, _ message: String) {
        precondition(condition, message)
    }
}
