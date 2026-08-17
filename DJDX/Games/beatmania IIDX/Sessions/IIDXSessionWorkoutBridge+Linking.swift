import Foundation
import HealthKit

@MainActor
extension IIDXSessionWorkoutBridge {

    static let linkLookback: TimeInterval = 45.0 * 24.0 * 60.0 * 60.0
    static let linkSearchPadding: TimeInterval = 60.0 * 60.0
    static let linkMinimumOverlap: TimeInterval = 30.0
    static let minimumAdoptableWorkout: TimeInterval = 180.0
    static let linkSweepInterval: TimeInterval = 15.0 * 60.0

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
        if let last = lastWorkoutLinkSweep, Date.now.timeIntervalSince(last) < Self.linkSweepInterval {
            return
        }
        lastWorkoutLinkSweep = .now
        let horizon = Date.now.addingTimeInterval(-Self.linkLookback)
        let workouts = await djdxWorkouts(
            from: horizon.addingTimeInterval(-Self.linkSearchPadding),
            to: .now
        )
        guard !workouts.isEmpty else { return }

        let sessions = database.allSessions()
        var claimed = Set(sessions.compactMap(\.workoutUUID))
        var didChange = link(sessions: sessions, to: workouts, claimed: &claimed, since: horizon)
        if adoptOrphanedWorkouts(workouts, sessions: sessions, claimed: &claimed) {
            didChange = true
        }
        if didChange {
            NotificationCenter.default.post(name: .playSessionDidChange, object: nil)
        }
    }

    private func link(sessions: [IIDXPlaySession],
                      to workouts: [HKWorkout],
                      claimed: inout Set<String>,
                      since horizon: Date) -> Bool {
        var didLink = false
        let unlinked = sessions
            .filter { $0.workoutUUID == nil && $0.endDate != nil && $0.startDate >= horizon }
            .sorted { $0.startDate < $1.startDate }
        for session in unlinked {
            guard let end = session.endDate,
                  let matched = Self.bestWorkout(
                    start: session.startDate, end: end, in: workouts, claimed: claimed
                  ) else { continue }
            session.workoutUUID = matched.uuid.uuidString
            database.updateSession(session)
            claimed.insert(matched.uuid.uuidString)
            didLink = true
        }
        return didLink
    }

    private func adoptOrphanedWorkouts(_ workouts: [HKWorkout],
                                       sessions: [IIDXPlaySession],
                                       claimed: inout Set<String>) -> Bool {
        let dismissed = Self.dismissedWorkoutUUIDs
        var occupied = sessions.map { (start: $0.startDate, end: $0.endDate ?? Date.now) }
        var didAdopt = false
        let orphans = workouts.sorted {
            $0.endDate.timeIntervalSince($0.startDate) > $1.endDate.timeIntervalSince($1.startDate)
        }
        for workout in orphans {
            let uuid = workout.uuid.uuidString
            guard !claimed.contains(uuid), !dismissed.contains(uuid),
                  workout.endDate.timeIntervalSince(workout.startDate) >= Self.minimumAdoptableWorkout,
                  !occupied.contains(where: {
                      min($0.end, workout.endDate) > max($0.start, workout.startDate)
                  }) else { continue }
            database.createSession(IIDXPlaySession(
                game: .iidxArcade,
                startDate: workout.startDate,
                endDate: workout.endDate,
                workoutUUID: uuid
            ))
            occupied.append((workout.startDate, workout.endDate))
            claimed.insert(uuid)
            didAdopt = true
        }
        return didAdopt
    }

    nonisolated static var dismissedWorkoutUUIDs: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: dismissedWorkoutUUIDsKey) ?? [])
    }

    nonisolated static func dismissWorkoutUUID(_ uuid: String) {
        var stored = UserDefaults.standard.stringArray(forKey: dismissedWorkoutUUIDsKey) ?? []
        guard !stored.contains(uuid) else { return }
        stored.append(uuid)
        if stored.count > 200 { stored.removeFirst(stored.count - 200) }
        UserDefaults.standard.set(stored, forKey: dismissedWorkoutUUIDsKey)
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
