import Foundation
import HealthKit

@MainActor
extension IIDXSessionWorkoutBridge {

    static let linkLookback: TimeInterval = 45.0 * 24.0 * 60.0 * 60.0
    static let linkSearchPadding: TimeInterval = 60.0 * 60.0
    static let linkMinimumOverlap: TimeInterval = 30.0

    @discardableResult
    func linkWorkout(toSessionID sessionID: String) async -> Bool {
        guard isEnabled, HKHealthStore.isHealthDataAvailable(),
              let session = database.session(id: sessionID),
              session.workoutUUID == nil else { return false }
        let end = session.endDate ?? .now
        let candidates = await djdxWorkouts(
            from: session.startDate.addingTimeInterval(-Self.linkSearchPadding),
            to: end.addingTimeInterval(Self.linkSearchPadding)
        )
        guard let matched = Self.bestWorkout(
            start: session.startDate, end: end,
            in: candidates, claimed: claimedWorkoutUUIDs(excluding: sessionID)
        ) else { return false }
        session.workoutUUID = matched.uuid.uuidString
        database.updateSession(session)
        NotificationCenter.default.post(name: .playSessionDidChange, object: sessionID)
        return true
    }

    func reconcileWorkoutLinks() async {
        flushPendingWorkoutUUIDs()
        guard isEnabled, HKHealthStore.isHealthDataAvailable() else { return }
        let horizon = Date.now.addingTimeInterval(-Self.linkLookback)
        let unlinked = database.allSessions()
            .filter { $0.startDate >= horizon && $0.workoutUUID == nil && $0.endDate != nil }
            .sorted { $0.startDate < $1.startDate }
        guard let earliest = unlinked.first?.startDate,
              let latest = unlinked.compactMap(\.endDate).max() else { return }

        let candidates = await djdxWorkouts(
            from: earliest.addingTimeInterval(-Self.linkSearchPadding),
            to: latest.addingTimeInterval(Self.linkSearchPadding)
        )
        guard !candidates.isEmpty else { return }

        var claimed = claimedWorkoutUUIDs(excluding: nil)
        var didLink = false
        for session in unlinked {
            guard let end = session.endDate,
                  let matched = Self.bestWorkout(
                    start: session.startDate, end: end, in: candidates, claimed: claimed
                  ) else { continue }
            session.workoutUUID = matched.uuid.uuidString
            database.updateSession(session)
            claimed.insert(matched.uuid.uuidString)
            didLink = true
        }
        if didLink {
            NotificationCenter.default.post(name: .playSessionDidChange, object: nil)
        }
    }

    private func claimedWorkoutUUIDs(excluding sessionID: String?) -> Set<String> {
        Set(database.allSessions()
            .filter { $0.id != sessionID }
            .compactMap(\.workoutUUID))
    }

    private static func bestWorkout(start: Date,
                                    end: Date,
                                    in workouts: [HKWorkout],
                                    claimed: Set<String>) -> HKWorkout? {
        let span = max(1.0, end.timeIntervalSince(start))
        var best: (workout: HKWorkout, overlap: TimeInterval)?
        for workout in workouts where !claimed.contains(workout.uuid.uuidString) {
            let overlap = min(end, workout.endDate).timeIntervalSince(max(start, workout.startDate))
            guard overlap >= linkMinimumOverlap else { continue }
            let workoutSpan = max(1.0, workout.endDate.timeIntervalSince(workout.startDate))
            guard overlap / span >= 0.5 || overlap / workoutSpan >= 0.5 else { continue }
            if best == nil || overlap > best!.overlap { best = (workout, overlap) }
        }
        return best?.workout
    }

    private func djdxWorkouts(from start: Date, to end: Date) async -> [HKWorkout] {
        let prefix = Bundle.main.bundleIdentifier ?? "com.tsubuzaki.DJDX"
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForSamples(withStart: start, end: end, options: []),
            HKQuery.predicateForWorkouts(with: .fitnessGaming)
        ])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                let workouts = (samples as? [HKWorkout] ?? []).filter {
                    $0.sourceRevision.source.bundleIdentifier.hasPrefix(prefix)
                }
                continuation.resume(returning: workouts)
            }
            healthStore.execute(query)
        }
    }
}
