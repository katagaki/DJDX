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
    nonisolated static let dismissedWorkoutUUIDsKey = "Sessions.DismissedWorkoutUUIDs"

    @Published var heartRate: Int = 0
    @Published var activeCalories: Int = 0
    @Published var isWorkoutActive: Bool = false
    @Published var isPaused: Bool = false
    @Published private(set) var isStartingWatch = false
    @Published private(set) var recordingIssueKey: String?
    @Published private(set) var runningStart: Date?
    @Published private(set) var pausedElapsed: TimeInterval?

    let healthStore = HKHealthStore()
    let database = IIDXPlaySessionsDatabase.shared
    private var activeSessionID: String?
    private var workoutStart: Date?
    private var sessionClock: SessionElapsedClock?
    private static let sessionClockKey = "Sessions.ElapsedClock"
    private var watchWorkoutConfirmed = false
    private var rearmedSessionIDs: Set<String> = []
    private var pendingLaunchSessionID: String?
    private var launchAttemptID: UUID?
    private var startTimeout: Task<Void, Never>?
    private var fallbackSavesInFlight: Set<String> = []
    private var pendingControlMessages: [[String: Any]] {
        get { UserDefaults.standard.array(forKey: "Sessions.PendingWatchCommands") as? [[String: Any]] ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "Sessions.PendingWatchCommands") }
    }

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
        if !isResuming || sessionClock == nil { restoreSessionClock(for: session) }
        watchWorkoutConfirmed = isResuming ? watchWorkoutConfirmed : false
        if !isResuming {
            heartRate = 0
            activeCalories = 0
        }
        isWorkoutActive = isEnabled
        if isEnabled {
            if !watchWorkoutConfirmed { retryWatchWorkout() }
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
        guard let activeSessionID, var clock = sessionClock, clock.isPaused != paused else { return }
        clock.setPaused(paused, at: Date(), origin: "phone")
        applySessionClock(clock)
        if isWorkoutActive { sendSessionClock(sessionID: activeSessionID) }
    }

    private func sendSessionClock(sessionID: String) {
        guard let clock = sessionClock else { return }
        var message: [String: Any] = ["command": "setPaused", "sessionID": sessionID, "paused": clock.isPaused]
        message["timer"] = clock.encoded
        send(message)
    }

    private func restoreSessionClock(for session: IIDXPlaySession) {
        let stored = UserDefaults.standard.dictionary(forKey: Self.sessionClockKey)
        let restored = stored?["sessionID"] as? String == session.id
            ? SessionElapsedClock(data: stored?["timer"] as? Data) : nil
        applySessionClock(restored ?? SessionElapsedClock(start: session.startDate))
    }

    private func applySessionClock(_ clock: SessionElapsedClock) {
        sessionClock = clock
        runningStart = clock.runningStart
        pausedElapsed = clock.pausedElapsed
        isPaused = clock.isPaused
        guard let activeSessionID else { return }
        if let data = clock.encoded {
            UserDefaults.standard.set(["sessionID": activeSessionID, "timer": data], forKey: Self.sessionClockKey)
        }
        IIDXSessionLiveActivityController.shared.updatePauseState(
            sessionID: activeSessionID,
            isPaused: isPaused,
            pausedElapsed: pausedElapsed,
            runningStart: isPaused ? nil : runningStart
        )
    }

    private func mergeSessionClock(_ clock: SessionElapsedClock?) {
        guard let clock else { return }
        if sessionClock.map({ clock.supersedes($0) }) ?? true { applySessionClock(clock) }
    }

    func reconcileActiveSession() {
        Task { @MainActor in await reconcileWorkoutLinks() }
        guard let session = database.activeSession(), session.isActive else { return }
        if activeSessionID == nil {
            activeSessionID = session.id
            workoutStart = session.startDate
            restoreSessionClock(for: session)
            isWorkoutActive = isEnabled
        }
        if isWorkoutActive {
            send(["command": "requestWorkoutState", "sessionID": session.id])
            if !watchWorkoutConfirmed, !isStartingWatch, recordingIssueKey == nil { retryWatchWorkout() }
        }
    }

    func retryWatchWorkout() {
        guard isEnabled, let activeSessionID,
              let session = database.session(id: activeSessionID), session.isActive else { return }
        beginWatchStartAttempt()
        pendingLaunchSessionID = activeSessionID
        sendStartCommand(session: session)
        launchWatchApp()
    }

    private func beginWatchStartAttempt() {
        recordingIssueKey = nil
        isStartingWatch = true
        watchWorkoutConfirmed = false
        let attemptID = UUID()
        launchAttemptID = attemptID
        startTimeout?.cancel()
        startTimeout = Task { @MainActor in
            do { try await Task.sleep(for: .seconds(45)) } catch { return }
            guard launchAttemptID == attemptID, !watchWorkoutConfirmed else { return }
            isStartingWatch = false
            recordingIssueKey = "Sessions.Watch.NotRecording"
        }
    }

    private func launchWatchApp() {
        guard let sessionID = pendingLaunchSessionID, sessionID == activeSessionID,
              isEnabled, let session = database.session(id: sessionID), session.isActive else { return }
        let connectivity = WCSession.default
        // Activation is asynchronous. Keep the launch pending until its delegate callback.
        guard connectivity.activationState == .activated else { return }
        pendingLaunchSessionID = nil
        guard HKHealthStore.isHealthDataAvailable(), connectivity.isPaired,
              connectivity.isWatchAppInstalled else {
            isStartingWatch = false
            recordingIssueKey = "Sessions.Watch.Unavailable"
            startTimeout?.cancel()
            return
        }
        let attemptID = launchAttemptID
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .fitnessGaming
        configuration.locationType = .indoor
        healthStore.startWatchApp(with: configuration) { [weak self] success, error in
            if let error { debugPrint("Watch launch failed: \(error)") }
            Task { @MainActor in
                guard let self, self.launchAttemptID == attemptID,
                      self.activeSessionID == sessionID, !self.watchWorkoutConfirmed else { return }
                if !success {
                    self.isStartingWatch = false
                    self.recordingIssueKey = "Sessions.Watch.NotRecording"
                    self.startTimeout?.cancel()
                }
            }
        }
    }

    private func confirmWatchRecording() {
        watchWorkoutConfirmed = true
        pendingLaunchSessionID = nil
        isStartingWatch = false
        recordingIssueKey = nil
        startTimeout?.cancel()
    }

    fileprivate func watchSessionSnapshot(retry: Bool, remoteSessionID: String?,
                                          remoteClock: SessionElapsedClock?) -> [String: Any] {
        guard isEnabled, let session = database.activeSession(), session.isActive else {
            return ["active": false]
        }
        adoptSessionIfNeeded(session.id)
        if remoteSessionID == session.id { mergeSessionClock(remoteClock) }
        if retry { beginWatchStartAttempt() }
        var snapshot: [String: Any] = [
            "active": true,
            "sessionID": session.id,
            "start": session.startDate.timeIntervalSince1970,
            "startAttemptID": launchAttemptID?.uuidString ?? session.id,
            "paused": isPaused
        ]
        snapshot["timer"] = sessionClock?.encoded
        return snapshot
    }

    fileprivate func connectivityActivated() {
        let messages = pendingControlMessages
        pendingControlMessages.removeAll()
        for message in messages { send(message) }
        syncProfileToWatch()
        resendStartIfActive()
        launchWatchApp()
    }

    fileprivate func resendStartIfActive() {
        guard isWorkoutActive, let activeSessionID,
              let session = database.session(id: activeSessionID), session.isActive else { return }
        sendStartCommand(session: session)
    }

    func endWorkout(session: IIDXPlaySession) {
        let wasTracking = activeSessionID == session.id
        if isEnabled || wasTracking {
            cancelQueuedTransfers(sessionID: session.id)
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
        startTimeout?.cancel()
        pendingLaunchSessionID = nil
        launchAttemptID = nil
        isStartingWatch = false
        recordingIssueKey = nil
        isWorkoutActive = false
        isPaused = false
        activeSessionID = nil
        workoutStart = nil
        sessionClock = nil
        UserDefaults.standard.removeObject(forKey: Self.sessionClockKey)
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
        let start = session.startDate
        let end = session.endDate ?? Date()
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

    private func cancelQueuedTransfers(sessionID: String) {
        pendingControlMessages.removeAll { $0["sessionID"] as? String == sessionID }
        for transfer in WCSession.default.outstandingUserInfoTransfers
        where transfer.userInfo["sessionID"] as? String == sessionID
            && transfer.userInfo["command"] as? String != "end" {
            transfer.cancel()
        }
    }

    private func send(_ payload: [String: Any]) {
        let connectivity = WCSession.default
        guard connectivity.activationState == .activated else {
            if payload["command"] as? String == "end" {
                pendingControlMessages.append(payload)
            }
            return
        }
        if payload["command"] as? String == "end" {
            connectivity.transferUserInfo(payload)
            if connectivity.isReachable { connectivity.sendMessage(payload, replyHandler: nil, errorHandler: nil) }
        } else if connectivity.isReachable {
            connectivity.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else if payload["command"] as? String == "start" {
            // This is a wake-up hint, never authority to resurrect a historical session.
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
        restoreSessionClock(for: session)
        isWorkoutActive = true
    }

    fileprivate func ingestMetrics(heartRate: Int?, activeCalories: Int?, sessionID: String) {
        adoptSessionIfNeeded(sessionID)
        guard sessionID == activeSessionID else { return }
        confirmWatchRecording()
        let previousHeartRate = self.heartRate
        let previousCalories = self.activeCalories
        if let heartRate { self.heartRate = heartRate }
        if let activeCalories { self.activeCalories = activeCalories }
        guard self.heartRate != previousHeartRate || self.activeCalories != previousCalories else { return }
        IIDXSessionLiveActivityController.shared.updateMetrics(
            sessionID: sessionID,
            heartRate: self.heartRate > 0 ? self.heartRate : nil,
            activeCalories: self.activeCalories > 0 ? self.activeCalories : nil
        )
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
        if let existing = database.session(id: sessionID) {
            guard existing.isActive else {
                send(["command": "end", "sessionID": sessionID])
                return
            }
        } else {
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
            if sessionID == activeSessionID {
                watchWorkoutConfirmed = false
            } else if let stored = database.session(id: sessionID), !stored.isActive {
                resolveWorkoutRecord(for: stored, watchConfirmed: false)
            }
            return
        }
        storeWorkoutUUID(uuid, sessionID: sessionID)
    }

    private func matchesWatchAttempt(_ attempt: String?, sessionID: String) -> Bool {
        // Legacy and Watch-initiated workouts have no phone launch generation.
        guard let attempt else { return true }
        return attempt == (launchAttemptID?.uuidString ?? sessionID)
    }

    fileprivate func applyWorkoutFailure(sessionID: String, reason: String?) {
        guard sessionID == activeSessionID else { return }
        watchWorkoutConfirmed = false
        isStartingWatch = false
        startTimeout?.cancel()
        recordingIssueKey = reason == "Watch.Recording.AuthorizationRequired"
            ? "Sessions.Watch.AuthorizationRequired" : "Sessions.Watch.NotRecording"
    }

    fileprivate func applyWorkoutStarted(sessionID: String) {
        adoptSessionIfNeeded(sessionID)
        guard sessionID == activeSessionID else { return }
        confirmWatchRecording()
        // A pause may have changed while the Watch was still attaching its session ID.
        sendSessionClock(sessionID: sessionID)
    }

    fileprivate func applyWatchWorkoutStopped(sessionID: String) {
        guard sessionID == activeSessionID, isWorkoutActive,
              let session = database.session(id: sessionID), session.isActive else { return }
        watchWorkoutConfirmed = false
        guard rearmedSessionIDs.insert(sessionID).inserted else { return }
        sendStartCommand(session: session)
    }

    fileprivate func applyWorkoutState(sessionID: String, paused: Bool, clock: SessionElapsedClock?) {
        adoptSessionIfNeeded(sessionID)
        guard sessionID == activeSessionID else { return }
        confirmWatchRecording()
        if let clock {
            mergeSessionClock(clock)
        } else if isPaused != paused {
            // Older companions cannot supply exact timing. Never replace our start with their collection start.
            setWorkoutPaused(paused)
        }
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
        guard end > start, let stored = database.session(id: sessionID), stored.workoutUUID == nil,
              fallbackSavesInFlight.insert(sessionID).inserted else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .fitnessGaming
        configuration.locationType = .indoor
        let builder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration,
            device: .local()
        )
        builder.beginCollection(withStart: start) { [weak self] success, error in
            Task { @MainActor in
                guard let self else { return }
                guard success else {
                    self.completeFallbackSave(sessionID: sessionID, uuid: nil, error: error)
                    return
                }
                self.finishFallbackWorkout(builder, sessionID: sessionID, end: end)
            }
        }
    }

    private func finishFallbackWorkout(_ builder: HKWorkoutBuilder, sessionID: String, end: Date) {
        builder.endCollection(withEnd: end) { [weak self] success, error in
            guard success else {
                Task { @MainActor in self?.completeFallbackSave(sessionID: sessionID, uuid: nil, error: error) }
                return
            }
            builder.finishWorkout { workout, error in
                let uuid = workout?.uuid.uuidString
                Task { @MainActor in self?.completeFallbackSave(sessionID: sessionID, uuid: uuid, error: error) }
            }
        }
    }

    private func completeFallbackSave(sessionID: String, uuid: String?, error: Error?) {
        fallbackSavesInFlight.remove(sessionID)
        guard let uuid else {
            debugPrint("Fallback workout save failed for \(sessionID): \(String(describing: error))")
            return
        }
        // A late Watch record may have linked while the fallback was saving.
        guard let stored = database.session(id: sessionID), stored.workoutUUID == nil else { return }
        storeWorkoutUUID(uuid, sessionID: sessionID)
    }

}

extension IIDXSessionWorkoutBridge: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        guard activationState == .activated else { return }
        nonisolated(unsafe) let bridge = self
        Task { @MainActor in bridge.connectivityActivated() }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        Task { @MainActor in self.resendStartIfActive() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        route(message)
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        guard message["command"] as? String == "watchReady" else {
            replyHandler([:])
            route(message)
            return
        }
        let retry = message["retry"] as? Bool ?? false
        let watchInitiated = message["watchInitiated"] as? Bool ?? false
        let requestedID = message["sessionID"] as? String
        let start = message["start"] as? Double
        let clock = SessionElapsedClock(data: message["timer"] as? Data)
        // WatchConnectivity permits invoking its reply handler asynchronously on another queue.
        nonisolated(unsafe) let reply = replyHandler
        Task { @MainActor in
            if watchInitiated { self.handleRemoteStart(sessionID: requestedID, start: start) }
            reply(self.watchSessionSnapshot(retry: retry, remoteSessionID: requestedID, remoteClock: clock))
        }
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
            let attempt = message["startAttemptID"] as? String
            Task { @MainActor in
                if uuid == nil, sessionID == bridge.activeSessionID,
                   !bridge.matchesWatchAttempt(attempt, sessionID: sessionID) { return }
                bridge.applyWorkoutFinished(sessionID: sessionID, uuid: uuid)
            }
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

    private nonisolated func routeWorkoutAcknowledgement(_ command: String,
                                                         sessionID: String, message: [String: Any]) {
        let reason = message["reason"] as? String
        let attempt = message["startAttemptID"] as? String
        Task { @MainActor in
            guard self.matchesWatchAttempt(attempt, sessionID: sessionID) else { return }
            if command == "workoutFailed" {
                self.applyWorkoutFailure(sessionID: sessionID, reason: reason)
            } else {
                self.applyWorkoutStarted(sessionID: sessionID)
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
        case "workoutFailed", "workoutStarted":
            routeWorkoutAcknowledgement(command, sessionID: sessionID, message: message)
        case "workoutState":
            let paused = message["paused"] as? Bool ?? false
            let clock = SessionElapsedClock(data: message["timer"] as? Data)
            let running = message["running"] as? Bool ?? true
            let attempt = message["startAttemptID"] as? String
            Task { @MainActor in
                guard bridge.matchesWatchAttempt(attempt, sessionID: sessionID) else { return }
                guard running else {
                    bridge.applyWatchWorkoutStopped(sessionID: sessionID)
                    return
                }
                bridge.applyWorkoutState(
                    sessionID: sessionID, paused: paused, clock: clock
                )
            }
        default:
            break
        }
    }
}
