import Combine
import Foundation
import HealthKit
import UIKit
import WatchConnectivity

@MainActor
final class IIDXSessionWorkoutBridge: NSObject, ObservableObject {
    static let shared = IIDXSessionWorkoutBridge()

    static let healthKitEnabledKey = "Sessions.HealthKitEnabled"

    @Published var heartRate: Int = 0
    @Published var activeCalories: Int = 0
    @Published var isWorkoutActive: Bool = false

    private let healthStore = HKHealthStore()
    private let database = IIDXPlaySessionsDatabase.shared
    private var activeSessionID: String?
    private var workoutStart: Date?

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.healthKitEnabledKey)
    }

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

    func startWorkout(session: IIDXPlaySession) {
        guard isEnabled else { return }
        activeSessionID = session.id
        workoutStart = session.startDate
        isWorkoutActive = true
        heartRate = 0
        activeCalories = 0
        send(["command": "start", "sessionID": session.id])
    }

    func endWorkout(session: IIDXPlaySession) {
        guard isEnabled, activeSessionID == session.id else { return }
        send(["command": "end", "sessionID": session.id])
        if !WCSession.default.isPaired {
            saveFallbackWorkout(for: session)
        }
        isWorkoutActive = false
        activeSessionID = nil
        workoutStart = nil
        heartRate = 0
        activeCalories = 0
    }

    private func send(_ payload: [String: Any]) {
        let connectivity = WCSession.default
        guard connectivity.activationState == .activated else { return }
        if connectivity.isReachable {
            connectivity.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            connectivity.transferUserInfo(payload)
        }
    }

    func pushSessionInfo(
        sessionID: String,
        playCount: Int,
        lastSongTitle: String?,
        lastDJLevel: String?,
        lastClearType: String?,
        lastScore: Int?,
        lastResultSummary: String?,
        bestThisSession: String?
    ) {
        guard isWorkoutActive, sessionID == activeSessionID else { return }
        var payload: [String: Any] = ["sessionInfo": true, "sessionID": sessionID, "playCount": playCount]
        if let lastSongTitle { payload["lastSongTitle"] = lastSongTitle }
        if let lastDJLevel { payload["lastDJLevel"] = lastDJLevel }
        if let lastClearType { payload["lastClearType"] = lastClearType }
        if let lastScore { payload["lastScore"] = lastScore }
        if let lastResultSummary { payload["lastResultSummary"] = lastResultSummary }
        if let bestThisSession { payload["bestThisSession"] = bestThisSession }
        send(payload)
    }

    func syncProfileToWatch() {
        let connectivity = WCSession.default
        guard connectivity.activationState == .activated else { return }
        var context: [String: Any] = [:]
        let standard = UserDefaults.standard
        if let djName = standard.string(forKey: "Profile.IIDX.DJName") { context["djName"] = djName }
        if let spRank = standard.string(forKey: "Profile.IIDX.SPRank") { context["spRank"] = spRank }
        if let dpRank = standard.string(forKey: "Profile.IIDX.DPRank") { context["dpRank"] = dpRank }
        let shared = SharedContainer.defaults
        if let spRadar = radarValues(prefix: "NotesRadar.SP", defaults: shared) { context["spRadar"] = spRadar }
        if let dpRadar = radarValues(prefix: "NotesRadar.DP", defaults: shared) { context["dpRadar"] = dpRadar }
        if let qpro = watchQproImageData() { context["qpro"] = qpro }
        guard !context.isEmpty else { return }
        context["ts"] = Date.now.timeIntervalSince1970
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

    fileprivate func ingestMetrics(heartRate: Int?, activeCalories: Int?, sessionID: String) {
        guard sessionID == activeSessionID else { return }
        if let heartRate { self.heartRate = heartRate }
        if let activeCalories { self.activeCalories = activeCalories }
        IIDXSessionLiveActivityController.shared.updateMetrics(
            sessionID: sessionID,
            heartRate: self.heartRate > 0 ? self.heartRate : nil,
            activeCalories: self.activeCalories > 0 ? self.activeCalories : nil
        )
        NotificationCenter.default.post(name: .playSessionDidChange, object: sessionID)
    }

    fileprivate func storeWorkoutUUID(_ uuid: String, sessionID: String) {
        guard let session = database.session(id: sessionID) else { return }
        session.workoutUUID = uuid
        database.updateSession(session)
    }

    private func saveFallbackWorkout(for session: IIDXPlaySession) {
        guard let start = workoutStart else { return }
        let end = Date()
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .fitnessGaming
        configuration.locationType = .indoor
        let builder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration,
            device: .local()
        )
        let sessionID = session.id
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
            switch command {
            case "requestProfile":
                Task { @MainActor in bridge.syncProfileToWatch() }
            case "endSession":
                Task { @MainActor in
                    NotificationCenter.default.post(name: .endSessionRequested, object: sessionID)
                }
            default:
                break
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
}
