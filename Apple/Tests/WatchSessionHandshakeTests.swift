import Foundation

// Run: swiftc Shared/SessionElapsedClock.swift 'DJDX CHARGE/WatchSessionHandshake.swift' \
//      Tests/WatchSessionHandshakeTests.swift -o /tmp/djdx-watch-sync-tests && /tmp/djdx-watch-sync-tests
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
        testElapsedClock()
        print("Passed 12 handshake and 12 elapsed-clock regression checks")
    }

    private static func testElapsedClock() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        var phone = SessionElapsedClock(start: start)
        let delayedLaunch = start.addingTimeInterval(6 * 3600)
        var watch = SessionElapsedClock(data: phone.encoded)!
        expect(watch.elapsed(at: delayedLaunch) == 21_600,
               "A late Watch launch must display gameplay elapsed time, not collection elapsed time")
        expect(watch.runningStart == phone.runningStart, "Both displays use the same absolute timer anchor")
        phone.setPaused(true, at: start.addingTimeInterval(21_620), origin: "phone")
        watch = SessionElapsedClock(data: phone.encoded)!
        expect(watch.elapsed(at: delayedLaunch.addingTimeInterval(500)) == 21_620,
               "Delivery delay must not add time to a paused clock")
        phone.setPaused(false, at: start.addingTimeInterval(21_680), origin: "phone")
        watch = SessionElapsedClock(data: phone.encoded)!
        expect(watch.elapsed(at: start.addingTimeInterval(21_690)) == 21_630,
               "A resumed clock excludes the pause, including after delayed delivery")
        let staleReply = watch
        watch.setPaused(true, at: start.addingTimeInterval(21_700), origin: "watch")
        expect(!staleReply.supersedes(watch), "A stale handshake cannot undo a local Watch pause")
        expect(watch.supersedes(phone), "A Watch pause can synchronize back to the phone")
        phone = SessionElapsedClock(data: watch.encoded)!
        expect(phone.elapsed(at: start.addingTimeInterval(22_000)) == 21_640,
               "Persisting and restoring a paused phone must keep its exact elapsed time")
        watch.setPaused(false, at: start.addingTimeInterval(21_720), origin: "watch")
        phone = SessionElapsedClock(data: watch.encoded)!
        expect(phone.elapsed(at: start.addingTimeInterval(21_730)) == 21_650,
               "Multiple pauses must not accumulate communication delay")
        let revision = watch.revision
        watch.setPaused(false, at: start.addingTimeInterval(21_740), origin: "watch")
        expect(watch.revision == revision, "Duplicate resume callbacks must not reset the timer")
        phone.setPaused(true, at: start.addingTimeInterval(21_750), origin: "phone")
        watch.setPaused(true, at: start.addingTimeInterval(21_751), origin: "watch")
        expect(watch.supersedes(phone) && !phone.supersedes(watch),
               "Concurrent controls converge using a deterministic revision order")
        let snapshot = WatchSessionSnapshot(reply: ["active": true, "sessionID": "session", "timer": watch.encoded!])
        expect(snapshot?.clock == watch && snapshot?.paused == true,
               "A reconnect snapshot carries the full paused clock")
        expect(SessionElapsedClock(data: Data("invalid".utf8)) == nil, "Invalid timer data is rejected")
    }

    private static func expect(_ condition: Bool, _ message: String) {
        precondition(condition, message)
    }
}
