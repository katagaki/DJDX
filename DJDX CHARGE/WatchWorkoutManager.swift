import Combine
import Foundation
import HealthKit
import WatchConnectivity
import WidgetKit

// swiftlint:disable file_length

@MainActor
// swiftlint:disable:next type_body_length
final class WatchWorkoutManager: NSObject, ObservableObject {
    static let shared = WatchWorkoutManager()

    @Published var isRunning = false
    @Published private(set) var recordingIssueKey: String?
    private var attemptID: UUID?
    private var collectionStarting = false
    private var isEnding = false
    private var isFinishing = false
    private var failedSessionID: String?
    private var failedSessionStart: Date?
    private var attachmentTimeout: Task<Void, Never>?
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

    @Published var qproImageData: Data?
    @Published var djName: String?
    @Published var spRank: String?
    @Published var dpRank: String?
    @Published var spRadar: WatchRadarData?
    @Published var dpRadar: WatchRadarData?
    @Published var healthKitEnabled: Bool = false

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var sessionID: String?
    private var pendingSessionID: String?
    private var pendingSessionStart: Date?
    private var lastMetricsSend: Date?
    private var sentHeartRate: Int?
    private var sentActiveCalories: Int?

    private static let metricsInterval: TimeInterval = 5.0

    private static let endedSessionIDsKey = "Watch.EndedSessionIDs"

    private var endedSessionIDs: [String] {
        get { UserDefaults.standard.stringArray(forKey: Self.endedSessionIDsKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: Self.endedSessionIDsKey) }
    }

    private func markSessionEnded(_ id: String) {
        guard !id.isEmpty else { return }
        var ended = endedSessionIDs
        ended.removeAll { $0 == id }
        ended.append(id)
        if ended.count > 20 {
            ended.removeFirst(ended.count - 20)
        }
        endedSessionIDs = ended
    }

    private func isSessionEnded(_ id: String) -> Bool {
        endedSessionIDs.contains(id)
    }

    override private init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func handleRemoteWorkoutLaunch() {
        requestProfile()
        guard !isRunning, session == nil, builder == nil else { return }
        startDate = Date()
        startAuthorizedWorkout()
        let token = attemptID
        attachmentTimeout?.cancel()
        attachmentTimeout = Task { @MainActor in
            do { try await Task.sleep(for: .seconds(45)) } catch { return }
            guard attemptID == token, isRunning, sessionID == nil else { return }
            failWorkoutStart(issueKey: "Watch.Recording.ConnectionFailed")
        }
    }

    func activateSession(sessionID: String, at start: Date = Date()) {
        guard !sessionID.isEmpty, !isSessionEnded(sessionID) else { return }
        // A launch and a start command may arrive in either order, including during authorization.
        if isRunning, self.sessionID == nil {
            self.sessionID = sessionID
            attachmentTimeout?.cancel()
            // Keep the actual collection start; assigning an older date cannot recover missed samples.
            sendWorkoutStarted()
            return
        }
        if isRunning || session != nil || builder != nil {
            if sessionID == self.sessionID {
                sendWorkoutStarted()
                return
            }
            pendingSessionID = sessionID
            pendingSessionStart = start
            if isRunning { endWorkout() }
            return
        }
        self.sessionID = sessionID
        startDate = Date()
        startAuthorizedWorkout()
    }

    func retryWorkout() {
        if let failedSessionID {
            activateSession(sessionID: failedSessionID, at: failedSessionStart ?? Date())
        } else {
            handleRemoteWorkoutLaunch()
        }
    }

    private func startAuthorizedWorkout() {
        recordingIssueKey = nil
        isRunning = true
        isEnding = false
        isFinishing = false
        let token = UUID()
        attemptID = token
        let share: Set = [HKQuantityType.workoutType()]
        let read: Set = [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned)]
        guard HKHealthStore.isHealthDataAvailable() else {
            failWorkoutStart(issueKey: "Watch.Recording.AuthorizationRequired")
            return
        }
        healthStore.requestAuthorization(toShare: share, read: read) { [weak self] success, error in
            if let error { debugPrint("Watch authorization failed: \(error)") }
            Task { @MainActor in
                guard let self, self.attemptID == token, self.isRunning else { return }
                guard success, self.healthStore.authorizationStatus(for: .workoutType()) == .sharingAuthorized else {
                    self.failWorkoutStart(issueKey: "Watch.Recording.AuthorizationRequired")
                    return
                }
                self.beginWorkoutCollection()
            }
        }
    }

    private func beginWorkoutCollection() {
        guard isRunning, session == nil, let token = attemptID else { return }
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
            let start = Date()
            startDate = start
            collectionStarting = true
            session.startActivity(with: start)
            builder.beginCollection(withStart: start) { [weak self] success, error in
                if let error { debugPrint("Watch collection failed: \(error)") }
                Task { @MainActor in
                    guard let self, self.attemptID == token else { return }
                    self.collectionStarting = false
                    guard success else {
                        self.failWorkoutStart()
                        return
                    }
                    self.isCollecting = true
                    if self.isEnding {
                        self.stopWorkoutSession()
                    } else {
                        self.sendWorkoutStarted()
                    }
                }
            }
        } catch {
            debugPrint("Watch workout creation failed: \(error)")
            failWorkoutStart()
        }
    }

    private func sendWorkoutStarted() {
        guard isRunning, isCollecting, let sessionID, let startDate else { return }
        sendToPhone([
            "command": "workoutStarted",
            "sessionID": sessionID,
            "start": startDate.timeIntervalSince1970
        ])
    }

    private func reportFailure(_ issueKey: String) {
        recordingIssueKey = issueKey
        failedSessionID = sessionID
        failedSessionStart = startDate
        if let sessionID {
            sendToPhone(["command": "workoutFailed", "sessionID": sessionID, "reason": issueKey])
        }
    }

    private func failWorkoutStart(issueKey: String = "Watch.Recording.Failed") {
        reportFailure(issueKey)
        session?.delegate = nil
        session?.end()
        builder?.discardWorkout()
        isRunning = false
        finishUp(workoutUUID: nil, sessionID: sessionID)
    }

    func pauseWorkout() {
        requestPause(true)
    }

    func resumeWorkout() {
        requestPause(false)
    }

    fileprivate func setPaused(_ paused: Bool, sessionID: String) {
        guard sessionID.isEmpty || sessionID == self.sessionID else { return }
        requestPause(paused)
    }

    fileprivate func adoptSession(_ newID: String) {
        guard isRunning, !newID.isEmpty, newID != sessionID else { return }
        sessionID = newID
        sendWorkoutStarted()
        sendWorkoutState()
        ingest(heartRate: nil, activeCalories: nil)
    }

    private func requestPause(_ paused: Bool) {
        guard isCollecting, !isEnding, let session else { return }
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
        guard healthKitEnabled, !isRunning else { return }
        let sessionID = UUID().uuidString
        let start = Date()
        sendToPhone([
            "command": "startSession",
            "sessionID": sessionID,
            "start": start.timeIntervalSince1970
        ])
        activateSession(sessionID: sessionID, at: start)
    }

    func requestEndSession() {
        if let sessionID {
            markSessionEnded(sessionID)
            sendToPhone(["command": "endSession", "sessionID": sessionID])
        }
        endWorkout()
    }

    fileprivate func handleEndCommand(sessionID: String) {
        markSessionEnded(sessionID)
        if pendingSessionID == sessionID {
            pendingSessionID = nil
            pendingSessionStart = nil
        }
        guard sessionID.isEmpty || sessionID == self.sessionID else { return }
        if let current = self.sessionID {
            markSessionEnded(current)
        }
        endWorkout()
    }

    fileprivate func handleWorkoutState(_ state: HKWorkoutSessionState, date: Date) {
        switch state {
        case .paused: applyPaused(true, at: date)
        case .running: applyPaused(false, at: date)
        case .ended:
            if isEnding { finishCollection() } else if isRunning { endWorkout() }
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
        guard isCollecting, !isEnding, let sessionID else { return }
        var payload: [String: Any] = [
            "command": "workoutState", "sessionID": sessionID,
            "paused": isPaused, "running": isRunning
        ]
        if isPaused {
            payload["elapsed"] = pausedElapsed
        } else if let startDate {
            payload["start"] = startDate.timeIntervalSince1970
        }
        sendToPhone(payload)
    }

    private func reportWorkoutState(sessionID: String) {
        if isRunning, sessionID.isEmpty || sessionID == self.sessionID {
            sendWorkoutState()
            return
        }
        guard !sessionID.isEmpty else { return }
        sendToPhone([
            "command": "workoutState", "sessionID": sessionID,
            "paused": false, "running": false
        ])
    }

    func endWorkout() {
        guard isRunning else { return }
        isRunning = false
        isEnding = true
        attachmentTimeout?.cancel()
        // Do not end a builder while beginCollection is still in flight.
        guard !collectionStarting else { return }
        stopWorkoutSession()
    }

    private func stopWorkoutSession() {
        guard let session, builder != nil, isCollecting else {
            finishUp(workoutUUID: nil, sessionID: sessionID)
            return
        }
        if session.state == .ended {
            finishCollection()
        } else {
            session.end()
        }
    }

    private func finishCollection() {
        guard !isFinishing, let builder, let token = attemptID else { return }
        isFinishing = true
        guard let sid = sessionID else {
            builder.discardWorkout()
            finishUp(workoutUUID: nil, sessionID: nil)
            return
        }
        builder.endCollection(withEnd: Date()) { [weak self] success, error in
            if let error { debugPrint("Watch end collection failed: \(error)") }
            Task { @MainActor in
                guard let self, self.attemptID == token else { return }
                guard success else {
                    self.reportFailure("Watch.Recording.SaveFailed")
                    builder.discardWorkout()
                    self.finishUp(workoutUUID: nil, sessionID: sid)
                    return
                }
                self.saveWorkout(builder, sessionID: sid, token: token)
            }
        }
    }

    private func saveWorkout(_ builder: HKLiveWorkoutBuilder, sessionID: String, token: UUID) {
        builder.finishWorkout { [weak self] workout, error in
            if let error { debugPrint("Watch save failed: \(error)") }
            let uuid = workout?.uuid.uuidString
            Task { @MainActor in
                guard let self, self.attemptID == token else { return }
                if uuid == nil { self.reportFailure("Watch.Recording.SaveFailed") }
                self.finishUp(workoutUUID: uuid, sessionID: sessionID)
            }
        }
    }

    private func finishUp(workoutUUID: String?, sessionID: String?) {
        attachmentTimeout?.cancel()
        attemptID = nil
        collectionStarting = false
        isEnding = false
        isFinishing = false
        isRunning = false
        session?.delegate = nil
        builder?.delegate = nil
        if let sessionID {
            var payload: [String: Any] = ["sessionID": sessionID, "workoutFinished": true]
            if let workoutUUID { payload["workoutUUID"] = workoutUUID }
            sendToPhone(payload)
        }
        session = nil
        builder = nil
        self.sessionID = nil
        heartRate = 0
        activeCalories = 0
        lastMetricsSend = nil
        sentHeartRate = nil
        sentActiveCalories = nil
        startDate = nil
        isPaused = false
        isCollecting = false
        pausedElapsed = 0
        resetSessionInfo()
        if let pendingSessionID {
            let start = pendingSessionStart ?? Date()
            self.pendingSessionID = nil
            pendingSessionStart = nil
            activateSession(sessionID: pendingSessionID, at: start)
        }
    }

    private func resetSessionInfo() {
        playCount = 0
        lastSongTitle = nil
        lastDJLevel = nil
        lastClearType = nil
        lastScore = nil
        lastResultSummary = nil
    }

    fileprivate func applySessionInfo(_ message: [String: Any]) {
        if let playCount = message["playCount"] as? Int { self.playCount = playCount }
        lastSongTitle = message["lastSongTitle"] as? String
        lastDJLevel = message["lastDJLevel"] as? String
        lastClearType = message["lastClearType"] as? String
        lastScore = message["lastScore"] as? Int
        lastResultSummary = message["lastResultSummary"] as? String
    }

    fileprivate func applyProfile(_ context: [String: Any]) {
        if let enabled = context["healthKitEnabled"] as? Bool { healthKitEnabled = enabled }
        if let djName = context["djName"] as? String { self.djName = djName.isEmpty ? nil : djName }
        if let spRank = context["spRank"] as? String { self.spRank = spRank.isEmpty ? nil : spRank }
        if let dpRank = context["dpRank"] as? String { self.dpRank = dpRank.isEmpty ? nil : dpRank }
        if let values = context["spRadar"] as? [Double] {
            spRadar = values.isEmpty ? nil : WatchRadarData(values: values)
        }
        if let values = context["dpRadar"] as? [Double] {
            dpRadar = values.isEmpty ? nil : WatchRadarData(values: values)
        }
        if let qpro = context["qpro"] as? Data { qproImageData = qpro.isEmpty ? nil : qpro }
        persistComplicationRadar(context)
    }

    private func persistComplicationRadar(_ context: [String: Any]) {
        guard let shared = UserDefaults(suiteName: "group.com.tsubuzaki.DJDX") else { return }
        var changed = false
        if let singlePlay = context["spRadar"] as? [Double] {
            if singlePlay.isEmpty { shared.removeObject(forKey: "Watch.Complication.RadarSP") } else {
                shared.set(singlePlay, forKey: "Watch.Complication.RadarSP")
            }
            changed = true
        }
        if let doublePlay = context["dpRadar"] as? [Double] {
            if doublePlay.isEmpty { shared.removeObject(forKey: "Watch.Complication.RadarDP") } else {
                shared.set(doublePlay, forKey: "Watch.Complication.RadarDP")
            }
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
        guard isRunning, isCollecting, let sessionID else { return }
        let changed = self.heartRate != sentHeartRate || self.activeCalories != sentActiveCalories
        guard changed else { return }
        let now = Date()
        if let lastMetricsSend = lastMetricsSend,
           now.timeIntervalSince(lastMetricsSend) < Self.metricsInterval {
            return
        }
        lastMetricsSend = now
        sentHeartRate = self.heartRate
        sentActiveCalories = self.activeCalories
        sendMetricsToPhone([
            "heartRate": self.heartRate,
            "activeCalories": self.activeCalories,
            "sessionID": sessionID
        ])
    }

    fileprivate func handleCommand(_ command: String, sessionID: String, start: Double?) {
        switch command {
        case "start":
            activateSession(
                sessionID: sessionID,
                at: start.map { Date(timeIntervalSince1970: $0) } ?? Date()
            )
        case "end": handleEndCommand(sessionID: sessionID)
        case "adoptSession": adoptSession(sessionID)
        case "requestWorkoutState": reportWorkoutState(sessionID: sessionID)
        default: break
        }
    }

    private func sendMetricsToPhone(_ payload: [String: Any]) {
        let connectivity = WCSession.default
        guard connectivity.activationState == .activated, connectivity.isReachable else { return }
        connectivity.sendMessage(payload, replyHandler: nil, errorHandler: nil)
    }

    private func sendToPhone(_ payload: [String: Any]) {
        let connectivity = WCSession.default
        guard connectivity.activationState == .activated else { return }
        if connectivity.isReachable {
            connectivity.sendMessage(payload, replyHandler: nil) { _ in
                connectivity.transferUserInfo(payload)
            }
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
        Task { @MainActor in
            guard manager.session === workoutSession else { return }
            manager.handleWorkoutState(toState, date: date)
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didFailWithError error: Error) {
        nonisolated(unsafe) let manager = self
        Task { @MainActor in
            guard manager.session === workoutSession else { return }
            debugPrint("Watch workout failed: \(error)")
            manager.reportFailure("Watch.Recording.Failed")
            if manager.isCollecting {
                manager.isRunning = false
                manager.isEnding = true
                manager.finishCollection()
            } else {
                manager.failWorkoutStart()
            }
        }
    }
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
        Task { @MainActor in
            guard manager.builder === workoutBuilder else { return }
            manager.ingest(heartRate: newHeartRate, activeCalories: newCalories)
        }
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
            let sessionID = message["sessionID"] as? String ?? ""
            if command == "setPaused" {
                let paused = message["paused"] as? Bool ?? false
                Task { @MainActor in manager.setPaused(paused, sessionID: sessionID) }
                return
            }
            let start = message["start"] as? Double
            Task { @MainActor in manager.handleCommand(command, sessionID: sessionID, start: start) }
            return
        }
        if message["sessionInfo"] != nil {
            Task { @MainActor in manager.applySessionInfo(message) }
        }
    }
}
