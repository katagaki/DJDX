import Combine
import Foundation
import HealthKit
import WatchConnectivity

@MainActor
final class SessionWorkoutBridge: NSObject, ObservableObject {
    static let shared = SessionWorkoutBridge()

    static let healthKitEnabledKey = "Sessions.HealthKitEnabled"

    @Published var heartRate: Int = 0
    @Published var activeCalories: Int = 0
    @Published var isWorkoutActive: Bool = false

    private let healthStore = HKHealthStore()
    private let database = PlaySessionsDatabase.shared
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

    func startWorkout(session: PlaySession) {
        guard isEnabled else { return }
        activeSessionID = session.id
        workoutStart = session.startDate
        isWorkoutActive = true
        heartRate = 0
        activeCalories = 0
        send(["command": "start", "sessionID": session.id])
    }

    func endWorkout(session: PlaySession) {
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

    fileprivate func ingestMetrics(heartRate: Int?, activeCalories: Int?, sessionID: String) {
        guard sessionID == activeSessionID else { return }
        if let heartRate { self.heartRate = heartRate }
        if let activeCalories { self.activeCalories = activeCalories }
        SessionLiveActivityController.shared.updateMetrics(
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

    private func saveFallbackWorkout(for session: PlaySession) {
        guard let start = workoutStart else { return }
        let end = Date()
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .cardioDance
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

extension SessionWorkoutBridge: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {}

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
