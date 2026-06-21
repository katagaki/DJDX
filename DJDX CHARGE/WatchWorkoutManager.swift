import Combine
import Foundation
import HealthKit
import WatchConnectivity
import WidgetKit

@MainActor
final class WatchWorkoutManager: NSObject, ObservableObject {
    @Published var isRunning = false
    @Published var isPaused = false
    @Published private(set) var isCollecting = false
    @Published var heartRate: Int = 0
    @Published var activeCalories: Int = 0
    @Published var startDate: Date?
    @Published private(set) var pausedElapsed: TimeInterval = 0

    @Published var playCount: Int = 0
    @Published var lastSongTitle: String?
    @Published var lastDJLevel: String?
    @Published var lastClearType: String?
    @Published var lastScore: Int?
    @Published var lastResultSummary: String?
    @Published var bestThisSession: String?

    @Published var qproImageData: Data?
    @Published var djName: String?
    @Published var spRank: String?
    @Published var dpRank: String?
    @Published var spRadar: WatchRadarData?
    @Published var dpRadar: WatchRadarData?

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var sessionID: String?

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func activateSession(sessionID: String) {
        guard !isRunning else { return }
        self.sessionID = sessionID
        startDate = Date()
        isRunning = true
        requestAuthorizationAndStartWorkout()
    }

    private func requestAuthorizationAndStartWorkout() {
        let share: Set = [HKQuantityType.workoutType()]
        let read: Set = [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned)]
        nonisolated(unsafe) let manager = self
        healthStore.requestAuthorization(toShare: share, read: read) { success, _ in
            guard success else { return }
            Task { @MainActor in manager.beginWorkoutCollection() }
        }
    }

    private func beginWorkoutCollection() {
        guard isRunning, session == nil, let start = startDate else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .fitnessGaming
        configuration.locationType = .indoor
        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder
            session.startActivity(with: start)
            builder.beginCollection(withStart: start) { _, _ in }
            isCollecting = true
        } catch {
            return
        }
    }

    func pauseWorkout() {
        requestPause(true)
    }

    func resumeWorkout() {
        requestPause(false)
    }

    fileprivate func setPaused(_ paused: Bool) {
        requestPause(paused)
    }

    // Only issue transitions that are valid from the session's current state —
    // HealthKit errors on pause-while-paused / resume-while-running. When the
    // session is already in the requested state, just reconcile our flag to it.
    private func requestPause(_ paused: Bool) {
        guard let session else { return }
        let date = Date()
        switch (paused, session.state) {
        case (true, .running):
            session.pause()
            applyPaused(true, at: date)
        case (false, .paused):
            session.resume()
            applyPaused(false, at: date)
        default:
            applyPaused(session.state == .paused, at: date)
        }
    }

    func requestStartSession() {
        guard !isRunning else { return }
        let sessionID = UUID().uuidString
        sendToPhone(["command": "startSession", "sessionID": sessionID])
        activateSession(sessionID: sessionID)
    }

    func requestEndSession() {
        if let sessionID {
            sendToPhone(["command": "endSession", "sessionID": sessionID])
        }
        endWorkout()
    }

    fileprivate func handleWorkoutState(_ state: HKWorkoutSessionState, date: Date) {
        switch state {
        case .paused: applyPaused(true, at: date)
        case .running: applyPaused(false, at: date)
        default: break
        }
    }

    private func applyPaused(_ paused: Bool, at date: Date) {
        if paused {
            guard isRunning, !isPaused, let startDate else { return }
            pausedElapsed = max(0, date.timeIntervalSince(startDate))
            isPaused = true
        } else {
            guard isPaused else { return }
            startDate = date.addingTimeInterval(-pausedElapsed)
            isPaused = false
        }
        sendWorkoutState()
    }

    private func sendWorkoutState() {
        guard let sessionID else { return }
        var payload: [String: Any] = ["command": "workoutState", "sessionID": sessionID, "paused": isPaused]
        if isPaused {
            payload["elapsed"] = pausedElapsed
        } else if let startDate {
            payload["start"] = startDate.timeIntervalSince1970
        }
        sendToPhone(payload)
    }

    func endWorkout() {
        guard isRunning else { return }
        isRunning = false
        let sid = sessionID
        guard let session, let builder else {
            finishUp(workoutUUID: nil, sessionID: sid)
            return
        }
        nonisolated(unsafe) let liveSession = session
        nonisolated(unsafe) let liveBuilder = builder
        nonisolated(unsafe) let manager = self
        let end = Date()
        liveSession.end()
        liveBuilder.endCollection(withEnd: end) { _, _ in
            liveBuilder.finishWorkout { workout, _ in
                let uuid = workout?.uuid.uuidString
                Task { @MainActor in manager.finishUp(workoutUUID: uuid, sessionID: sid) }
            }
        }
    }

    private func finishUp(workoutUUID: String?, sessionID: String?) {
        if let workoutUUID, let sessionID {
            sendToPhone(["workoutUUID": workoutUUID, "sessionID": sessionID])
        }
        session = nil
        builder = nil
        self.sessionID = nil
        heartRate = 0
        activeCalories = 0
        startDate = nil
        isPaused = false
        isCollecting = false
        pausedElapsed = 0
        resetSessionInfo()
    }

    private func resetSessionInfo() {
        playCount = 0
        lastSongTitle = nil
        lastDJLevel = nil
        lastClearType = nil
        lastScore = nil
        lastResultSummary = nil
        bestThisSession = nil
    }

    fileprivate func applySessionInfo(_ message: [String: Any]) {
        if let playCount = message["playCount"] as? Int { self.playCount = playCount }
        lastSongTitle = message["lastSongTitle"] as? String
        lastDJLevel = message["lastDJLevel"] as? String
        lastClearType = message["lastClearType"] as? String
        lastScore = message["lastScore"] as? Int
        lastResultSummary = message["lastResultSummary"] as? String
        bestThisSession = message["bestThisSession"] as? String
    }

    fileprivate func applyProfile(_ context: [String: Any]) {
        if let djName = context["djName"] as? String { self.djName = djName }
        if let spRank = context["spRank"] as? String { self.spRank = spRank }
        if let dpRank = context["dpRank"] as? String { self.dpRank = dpRank }
        if let values = context["spRadar"] as? [Double] { spRadar = WatchRadarData(values: values) }
        if let values = context["dpRadar"] as? [Double] { dpRadar = WatchRadarData(values: values) }
        if let qpro = context["qpro"] as? Data { qproImageData = qpro }
        persistComplicationRadar(context)
    }

    private func persistComplicationRadar(_ context: [String: Any]) {
        guard let shared = UserDefaults(suiteName: "group.com.tsubuzaki.DJDX") else { return }
        var changed = false
        if let sp = context["spRadar"] as? [Double] {
            shared.set(sp, forKey: "Watch.Complication.RadarSP")
            changed = true
        }
        if let dp = context["dpRadar"] as? [Double] {
            shared.set(dp, forKey: "Watch.Complication.RadarDP")
            changed = true
        }
        if changed {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    fileprivate func requestProfile() {
        let connectivity = WCSession.default
        guard connectivity.activationState == .activated, connectivity.isReachable else { return }
        connectivity.sendMessage(["command": "requestProfile"], replyHandler: nil, errorHandler: nil)
    }

    fileprivate func ingest(heartRate: Int?, activeCalories: Int?) {
        if let heartRate { self.heartRate = heartRate }
        if let activeCalories { self.activeCalories = activeCalories }
        guard let sessionID else { return }
        sendToPhone([
            "heartRate": self.heartRate,
            "activeCalories": self.activeCalories,
            "sessionID": sessionID
        ])
    }

    fileprivate func handleCommand(_ command: String, sessionID: String) {
        switch command {
        case "start": activateSession(sessionID: sessionID)
        case "end": endWorkout()
        default: break
        }
    }

    private func sendToPhone(_ payload: [String: Any]) {
        let connectivity = WCSession.default
        if connectivity.isReachable {
            connectivity.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            connectivity.transferUserInfo(payload)
        }
    }
}

extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState,
                                    date: Date) {
        nonisolated(unsafe) let manager = self
        Task { @MainActor in manager.handleWorkoutState(toState, date: date) }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didFailWithError error: Error) {}
}

extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                                    didCollectDataOf collectedTypes: Set<HKSampleType>) {
        nonisolated(unsafe) let manager = self
        var newHeartRate: Int?
        var newCalories: Int?
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType,
                  let statistics = workoutBuilder.statistics(for: quantityType) else { continue }
            if quantityType == HKQuantityType(.heartRate) {
                let unit = HKUnit.count().unitDivided(by: .minute())
                if let value = statistics.mostRecentQuantity()?.doubleValue(for: unit) {
                    newHeartRate = Int(value)
                }
            } else if quantityType == HKQuantityType(.activeEnergyBurned) {
                if let value = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                    newCalories = Int(value)
                }
            }
        }
        Task { @MainActor in manager.ingest(heartRate: newHeartRate, activeCalories: newCalories) }
    }
}

extension WatchWorkoutManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        guard activationState == .activated else { return }
        let context = session.receivedApplicationContext
        nonisolated(unsafe) let manager = self
        Task { @MainActor in
            if !context.isEmpty { manager.applyProfile(context) }
            manager.requestProfile()
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext applicationContext: [String: Any]) {
        nonisolated(unsafe) let manager = self
        Task { @MainActor in manager.applyProfile(applicationContext) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        route(message)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        route(userInfo)
    }

    private nonisolated func route(_ message: [String: Any]) {
        nonisolated(unsafe) let manager = self
        if let command = message["command"] as? String {
            if command == "setPaused" {
                let paused = message["paused"] as? Bool ?? false
                Task { @MainActor in manager.setPaused(paused) }
                return
            }
            let sessionID = message["sessionID"] as? String ?? ""
            Task { @MainActor in manager.handleCommand(command, sessionID: sessionID) }
            return
        }
        if message["sessionInfo"] != nil {
            Task { @MainActor in manager.applySessionInfo(message) }
        }
    }
}
