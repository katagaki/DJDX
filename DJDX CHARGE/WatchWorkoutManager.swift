import Combine
import Foundation
import HealthKit
import WatchConnectivity

@MainActor
final class WatchWorkoutManager: NSObject, ObservableObject {
    @Published var isRunning = false
    @Published var heartRate: Int = 0
    @Published var activeCalories: Int = 0
    @Published var startDate: Date?

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

    func requestAuthorizationAndStart(sessionID: String) {
        let share: Set = [HKQuantityType.workoutType()]
        let read: Set = [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned)]
        nonisolated(unsafe) let manager = self
        healthStore.requestAuthorization(toShare: share, read: read) { success, _ in
            guard success else { return }
            Task { @MainActor in manager.startWorkout(sessionID: sessionID) }
        }
    }

    private func startWorkout(sessionID: String) {
        guard session == nil else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .cardioDance
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
            self.sessionID = sessionID
            let start = Date()
            startDate = start
            session.startActivity(with: start)
            builder.beginCollection(withStart: start) { _, _ in }
            isRunning = true
        } catch {
            return
        }
    }

    func endWorkout() {
        guard let session, let builder else { return }
        isRunning = false
        let sid = sessionID
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
        case "start": requestAuthorizationAndStart(sessionID: sessionID)
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
                                    date: Date) {}

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
                             error: Error?) {}

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        route(message)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        route(userInfo)
    }

    private nonisolated func route(_ message: [String: Any]) {
        guard let command = message["command"] as? String else { return }
        let sessionID = message["sessionID"] as? String ?? ""
        nonisolated(unsafe) let manager = self
        Task { @MainActor in manager.handleCommand(command, sessionID: sessionID) }
    }
}
