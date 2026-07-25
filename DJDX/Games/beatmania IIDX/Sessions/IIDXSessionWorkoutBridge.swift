import Combine
import Foundation
import HealthKit
import UIKit
import WatchConnectivity

// swiftlint:disable file_length

@MainActor
// swiftlint:disable:next type_body_length
final class IIDXSessionWorkoutBridge: NSObject, ObservableObject {
    static let shared = IIDXSessionWorkoutBridge()

    static let healthKitEnabledKey = "Sessions.HealthKitEnabled"
    static let pendingWorkoutUUIDsKey = "Sessions.PendingWorkoutUUIDs"

    @Published var heartRate: Int = 0
    @Published var activeCalories: Int = 0
    @Published var isWorkoutActive: Bool = false
    @Published var isPaused: Bool = false
    @Published private(set) var runningStart: Date?
    @Published private(set) var pausedElapsed: TimeInterval?

    let healthStore = HKHealthStore()
    let database = IIDXPlaySessionsDatabase.shared
    private var activeSessionID: String?
    private var workoutStart: Date?
    private var watchWorkoutConfirmed = false
    private var rearmedSessionIDs: Set<String> = []

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.healthKitEnabledKey)
    }

    var isSessionActive: Bool { activeSessionID != nil }

    override private init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func activate() {}

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        let share: Set = [HKQuantityType.workoutType()]
        let read: Set = [
            HKQuantityType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned)
        ]
        return await withCheckedContinuation { continuation in
            healthStore.requestAuthorization(toShare: share, read: read) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }

    func heartRateRange(ending date: Date, window: TimeInterval = 60.0) async -> (min: Int, max: Int)? {
        guard isEnabled, HKHealthStore.isHealthDataAvailable() else { return nil }
        let heartRateType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(
            withStart: date.addingTimeInterval(-window),
            end: date,
            options: [.strictStartDate, .strictEndDate]
        )
        let unit = HKUnit.count().unitDivided(by: .minute())
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: heartRateType,
                quantitySamplePredicate: predicate,
                options: [.discreteMin, .discreteMax]
            ) { _, statistics, _ in
                guard let statistics,
                      let minQuantity = statistics.minimumQuantity(),
                      let maxQuantity = statistics.maximumQuantity() else {
                    continuation.resume(returning: nil)
                    return
                }
                let min = Int(minQuantity.doubleValue(for: unit).rounded())
                let max = Int(maxQuantity.doubleValue(for: unit).rounded())
                continuation.resume(returning: (min, max))
            }
            healthStore.execute(query)
        }
    }

    func heartRateSamples(from start: Date, to end: Date) async -> [(date: Date, bpm: Int)] {
        guard isEnabled, HKHealthStore.isHealthDataAvailable(), end > start else { return [] }
        let heartRateType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: [.strictStartDate, .strictEndDate]
        )
        let unit = HKUnit.count().unitDivided(by: .minute())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                let quantitySamples = (samples as? [HKQuantitySample]) ?? []
                let result = quantitySamples.map { sample in
                    (date: sample.startDate, bpm: Int(sample.quantity.doubleValue(for: unit).rounded()))
                }
                continuation.resume(returning: result)
            }
            healthStore.execute(query)
        }
    }

    func startWorkout(session: IIDXPlaySession) {
        let isResuming = activeSessionID == session.id
        activeSessionID = session.id
        workoutStart = session.startDate
        runningStart = isResuming ? (runningStart ?? session.startDate) : session.startDate
        pausedElapsed = isResuming ? pausedElapsed : nil
        isPaused = isResuming ? isPaused : false
        watchWorkoutConfirmed = isResuming ? watchWorkoutConfirmed : false
        if !isResuming {
            heartRate = 0
            activeCalories = 0
        }
        isWorkoutActive = isEnabled
        if isEnabled {
            sendStartCommand(session: session)
            launchWatchApp()
        }
    }

    private func sendStartCommand(session: IIDXPlaySession) {
        send([
            "command": "start",
            "sessionID": session.id,
            "start": session.startDate.timeIntervalSince1970
        ])
    }

    func setWorkoutPaused(_ paused: Bool) {
        guard let activeSessionID else { return }
        let now = Date()
        if paused {
            guard !isPaused else { return }
            let anchor = runningStart ?? workoutStart ?? now
            pausedElapsed = max(0, now.timeIntervalSince(anchor))
            isPaused = true
        } else {
            guard isPaused else { return }
            runningStart = now.addingTimeInterval(-(pausedElapsed ?? 0))
            pausedElapsed = nil
            isPaused = false
        }
        IIDXSessionLiveActivityController.shared.updatePauseState(
            sessionID: activeSessionID,
            isPaused: isPaused,
            pausedElapsed: isPaused ? pausedElapsed : nil,
            runningStart: isPaused ? nil : runningStart
        )
        if isWorkoutActive {
            send(["command": "setPaused", "sessionID": activeSessionID, "paused": paused])
        }
    }

    func reconcileActiveSession() {
        Task { @MainActor in await reconcileWorkoutLinks() }
        guard let session = database.activeSession(), session.isActive else { return }
        if activeSessionID == nil {
            activeSessionID = session.id
            workoutStart = session.startDate
            runningStart = runningStart ?? session.startDate
            isWorkoutActive = isEnabled
        }
        if isWorkoutActive {
            send(["command": "requestWorkoutState", "sessionID": session.id])
        }
    }

    private func launchWatchApp() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let connectivity = WCSession.default
        guard connectivity.activationState == .activated,
              connectivity.isPaired,
              connectivity.isWatchAppInstalled,
              !connectivity.isReachable else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .fitnessGaming
        configuration.locationType = .indoor
        healthStore.startWatchApp(with: configuration) { success, error in
            if !success {
                debugPrint("Failed to launch Watch app for session: \(String(describing: error))")
            }
        }
    }

    fileprivate func resendStartIfActive() {
        guard isWorkoutActive, let activeSessionID,
              let session = database.session(id: activeSessionID) else { return }
        sendStartCommand(session: session)
    }

    func endWorkout(session: IIDXPlaySession) {
        let wasTracking = activeSessionID == session.id
        if isEnabled || wasTracking {
            send(["command": "end", "sessionID": session.id])
        }
        if isEnabled {
            resolveWorkoutRecord(
                for: session,
                watchConfirmed: wasTracking && watchWorkoutConfirmed
            )
        }
        rearmedSessionIDs.remove(session.id)
        guard wasTracking else { return }
        isWorkoutActive = false
        isPaused = false
        activeSessionID = nil
        workoutStart = nil
        runningStart = nil
        pausedElapsed = nil
        watchWorkoutConfirmed = false
        heartRate = 0
        activeCalories = 0
    }

    private var watchCanRecordWorkout: Bool {
        let connectivity = WCSession.default
        return connectivity.activationState == .activated
            && connectivity.isPaired
            && connectivity.isWatchAppInstalled
    }

    private func resolveWorkoutRecord(for session: IIDXPlaySession, watchConfirmed: Bool) {
        let sessionID = session.id
        guard let stored = database.session(id: sessionID), stored.workoutUUID == nil else { return }
        let start = workoutStart ?? session.startDate
        let end = Date()
        guard watchConfirmed || watchCanRecordWorkout else {
            saveFallbackWorkout(sessionID: sessionID, start: start, end: end)
            return
        }
        let grace: Duration = watchConfirmed ? .seconds(45) : .seconds(15)
        Task { @MainActor in
            try? await Task.sleep(for: grace)
            guard let current = database.session(id: sessionID),
                  current.workoutUUID == nil else { return }
            if await linkWorkout(toSessionID: sessionID) { return }
            guard !watchConfirmed else { return }
            saveFallbackWorkout(sessionID: sessionID, start: start, end: end)
        }
    }

    private func send(_ payload: [String: Any]) {
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

    // swiftlint:disable:next function_parameter_count
    func pushSessionInfo(
        sessionID: String,
        playCount: Int,
        lastSongTitle: String?,
        lastDJLevel: String?,
        lastClearType: String?,
        lastScore: Int?,
        lastResultSummary: String?
    ) {
        guard isWorkoutActive, sessionID == activeSessionID else { return }
        var payload: [String: Any] = ["sessionInfo": true, "sessionID": sessionID, "playCount": playCount]
        if let lastSongTitle { payload["lastSongTitle"] = lastSongTitle }
        if let lastDJLevel { payload["lastDJLevel"] = lastDJLevel }
        if let lastClearType { payload["lastClearType"] = lastClearType }
        if let lastScore { payload["lastScore"] = lastScore }
        if let lastResultSummary { payload["lastResultSummary"] = lastResultSummary }
        send(payload)
    }

    func syncProfileToWatch() {
        let connectivity = WCSession.default
        guard connectivity.activationState == .activated else { return }
        let standard = UserDefaults.standard
        let shared = SharedContainer.defaults
        let context: [String: Any] = [
            "djName": standard.string(forKey: "Profile.IIDX.DJName") ?? "",
            "spRank": standard.string(forKey: "Profile.IIDX.SPRank") ?? "",
            "dpRank": standard.string(forKey: "Profile.IIDX.DPRank") ?? "",
            "spRadar": radarValues(prefix: "NotesRadar.SP", defaults: shared) ?? [],
            "dpRadar": radarValues(prefix: "NotesRadar.DP", defaults: shared) ?? [],
            "qpro": watchQproImageData() ?? Data(),
            "healthKitEnabled": isEnabled,
            "ts": Date.now.timeIntervalSince1970
        ]
        try? connectivity.updateApplicationContext(context)
    }

    private func radarValues(prefix: String, defaults: UserDefaults) -> [Double]? {
        guard defaults.object(forKey: "\(prefix).Notes") != nil else { return nil }
        return [
            defaults.double(forKey: "\(prefix).Notes"),
            defaults.double(forKey: "\(prefix).Chord"),
            defaults.double(forKey: "\(prefix).Peak"),
            defaults.double(forKey: "\(prefix).Charge"),
            defaults.double(forKey: "\(prefix).Scratch"),
            defaults.double(forKey: "\(prefix).Soflan")
        ]
    }

    private func watchQproImageData() -> Data? {
        let fileURL = SharedContainer.imagesURL.appendingPathComponent("Qpro.png")
        guard let image = UIImage(contentsOfFile: fileURL.path) else { return nil }
        let maxDimension: CGFloat = 240.0
        let scale = min(1.0, maxDimension / max(image.size.width, image.size.height))
        guard scale < 1.0 else { return image.pngData() }
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        let resized = UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.pngData()
    }

    private func adoptSessionIfNeeded(_ sessionID: String) {
        guard activeSessionID == nil,
              let session = database.session(id: sessionID), session.isActive else { return }
        activeSessionID = sessionID
        workoutStart = session.startDate
        runningStart = runningStart ?? session.startDate
        isWorkoutActive = true
    }

    fileprivate func ingestMetrics(heartRate: Int?, activeCalories: Int?, sessionID: String) {
        adoptSessionIfNeeded(sessionID)
        guard sessionID == activeSessionID else { return }
        watchWorkoutConfirmed = true
        if let heartRate { self.heartRate = heartRate }
        if let activeCalories { self.activeCalories = activeCalories }
        IIDXSessionLiveActivityController.shared.updateMetrics(
            sessionID: sessionID,
            heartRate: self.heartRate > 0 ? self.heartRate : nil,
            activeCalories: self.activeCalories > 0 ? self.activeCalories : nil
        )
        NotificationCenter.default.post(name: .playSessionDidChange, object: sessionID)
    }

    fileprivate func handleRemoteStart(sessionID: String?, start: Double?) {
        if let active = database.activeSession(), active.isActive {
            reconcileActiveSession()
            if active.id != sessionID {
                send(["command": "adoptSession", "sessionID": active.id])
            }
            return
        }
        guard let sessionID, !sessionID.isEmpty else {
            NotificationCenter.default.post(name: .startSessionRequested, object: nil)
            return
        }
        if database.session(id: sessionID) == nil {
            database.createSession(IIDXPlaySession(
                id: sessionID,
                game: .iidxArcade,
                startDate: start.map { Date(timeIntervalSince1970: $0) } ?? .now
            ))
        }
        flushPendingWorkoutUUIDs()
        NotificationCenter.default.post(name: .startSessionRequested, object: sessionID)
    }

    fileprivate func handleRemoteEnd(sessionID: String) {
        let requestedID = sessionID.isEmpty ? nil : sessionID
        NotificationCenter.default.post(name: .endSessionRequested, object: requestedID)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            let resolved = requestedID.flatMap { database.session(id: $0) } ?? database.activeSession()
            guard let session = resolved, session.isActive,
                  database.endSession(id: session.id) else { return }
            endWorkout(session: session)
            NotificationCenter.default.post(name: .playSessionDidChange, object: session.id)
        }
    }

    fileprivate func applyWorkoutFinished(sessionID: String, uuid: String?) {
        guard let uuid else {
            if sessionID == activeSessionID { watchWorkoutConfirmed = false }
            return
        }
        storeWorkoutUUID(uuid, sessionID: sessionID)
    }

    fileprivate func applyWorkoutStarted(sessionID: String) {
        adoptSessionIfNeeded(sessionID)
        guard sessionID == activeSessionID else { return }
        watchWorkoutConfirmed = true
    }

    fileprivate func applyWatchWorkoutStopped(sessionID: String) {
        guard sessionID == activeSessionID, isWorkoutActive,
              let session = database.session(id: sessionID), session.isActive else { return }
        watchWorkoutConfirmed = false
        guard rearmedSessionIDs.insert(sessionID).inserted else { return }
        sendStartCommand(session: session)
    }

    fileprivate func applyWorkoutState(sessionID: String, paused: Bool, elapsed: Double?, start: Double?) {
        adoptSessionIfNeeded(sessionID)
        guard sessionID == activeSessionID else { return }
        watchWorkoutConfirmed = true
        isPaused = paused
        if paused {
            if let elapsed { pausedElapsed = elapsed }
        } else {
            if let start { runningStart = Date(timeIntervalSince1970: start) }
            pausedElapsed = nil
        }
        IIDXSessionLiveActivityController.shared.updatePauseState(
            sessionID: sessionID,
            isPaused: paused,
            pausedElapsed: paused ? pausedElapsed : nil,
            runningStart: paused ? nil : runningStart
        )
    }

    fileprivate func storeWorkoutUUID(_ uuid: String, sessionID: String) {
        if sessionID == activeSessionID { watchWorkoutConfirmed = true }
        guard let session = database.session(id: sessionID) else {
            bufferWorkoutUUID(uuid, sessionID: sessionID)
            return
        }
        session.workoutUUID = uuid
        database.updateSession(session)
        removeBufferedWorkoutUUID(sessionID: sessionID)
        NotificationCenter.default.post(name: .playSessionDidChange, object: sessionID)
    }

    private var pendingWorkoutUUIDs: [String: String] {
        get {
            UserDefaults.standard.dictionary(
                forKey: Self.pendingWorkoutUUIDsKey
            ) as? [String: String] ?? [:]
        }
        set { UserDefaults.standard.set(newValue, forKey: Self.pendingWorkoutUUIDsKey) }
    }

    private func bufferWorkoutUUID(_ uuid: String, sessionID: String) {
        var pending = pendingWorkoutUUIDs
        if pending.count >= 20, pending[sessionID] == nil,
           let oldest = pending.keys.sorted().first {
            pending[oldest] = nil
        }
        pending[sessionID] = uuid
        pendingWorkoutUUIDs = pending
    }

    private func removeBufferedWorkoutUUID(sessionID: String) {
        var pending = pendingWorkoutUUIDs
        guard pending.removeValue(forKey: sessionID) != nil else { return }
        pendingWorkoutUUIDs = pending
    }

    func flushPendingWorkoutUUIDs() {
        var pending = pendingWorkoutUUIDs
        guard !pending.isEmpty else { return }
        var didLink = false
        for (sessionID, uuid) in pending {
            guard let session = database.session(id: sessionID) else { continue }
            if session.workoutUUID == nil {
                session.workoutUUID = uuid
                database.updateSession(session)
                didLink = true
            }
            pending[sessionID] = nil
        }
        pendingWorkoutUUIDs = pending
        if didLink {
            NotificationCenter.default.post(name: .playSessionDidChange, object: nil)
        }
    }

    private func saveFallbackWorkout(sessionID: String, start: Date, end: Date) {
        guard end > start else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .fitnessGaming
        configuration.locationType = .indoor
        let builder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration,
            device: .local()
        )
        nonisolated(unsafe) let liveBuilder = builder
        nonisolated(unsafe) let bridge = self
        liveBuilder.beginCollection(withStart: start) { _, _ in
            liveBuilder.endCollection(withEnd: end) { _, _ in
                liveBuilder.finishWorkout { workout, _ in
                    guard let uuid = workout?.uuid.uuidString else { return }
                    Task { @MainActor in bridge.storeWorkoutUUID(uuid, sessionID: sessionID) }
                }
            }
        }
    }
}

extension IIDXSessionWorkoutBridge: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        guard activationState == .activated else { return }
        nonisolated(unsafe) let bridge = self
        Task { @MainActor in bridge.syncProfileToWatch() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        route(message)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        route(userInfo)
    }

    private nonisolated func route(_ message: [String: Any]) {
        let sessionID = message["sessionID"] as? String ?? ""
        nonisolated(unsafe) let bridge = self
        if let command = message["command"] as? String {
            routeCommand(command, sessionID: sessionID, message: message)
            return
        }
        if message["workoutFinished"] != nil {
            let uuid = message["workoutUUID"] as? String
            Task { @MainActor in bridge.applyWorkoutFinished(sessionID: sessionID, uuid: uuid) }
            return
        }
        if let uuid = message["workoutUUID"] as? String {
            Task { @MainActor in bridge.storeWorkoutUUID(uuid, sessionID: sessionID) }
            return
        }
        let heartRate = message["heartRate"] as? Int
        let activeCalories = message["activeCalories"] as? Int
        if heartRate != nil || activeCalories != nil {
            Task { @MainActor in
                bridge.ingestMetrics(heartRate: heartRate, activeCalories: activeCalories, sessionID: sessionID)
            }
        }
    }

    private nonisolated func routeCommand(_ command: String,
                                          sessionID: String,
                                          message: [String: Any]) {
        nonisolated(unsafe) let bridge = self
        switch command {
        case "requestProfile":
            Task { @MainActor in
                bridge.syncProfileToWatch()
                bridge.resendStartIfActive()
            }
        case "startSession":
            let requestedID = sessionID.isEmpty ? nil : sessionID
            let start = message["start"] as? Double
            Task { @MainActor in bridge.handleRemoteStart(sessionID: requestedID, start: start) }
        case "endSession":
            Task { @MainActor in bridge.handleRemoteEnd(sessionID: sessionID) }
        case "workoutStarted":
            Task { @MainActor in bridge.applyWorkoutStarted(sessionID: sessionID) }
        case "workoutState":
            let paused = message["paused"] as? Bool ?? false
            let elapsed = message["elapsed"] as? Double
            let start = message["start"] as? Double
            let running = message["running"] as? Bool ?? true
            Task { @MainActor in
                guard running else {
                    bridge.applyWatchWorkoutStopped(sessionID: sessionID)
                    return
                }
                bridge.applyWorkoutState(
                    sessionID: sessionID, paused: paused, elapsed: elapsed, start: start
                )
            }
        default:
            break
        }
    }
}
