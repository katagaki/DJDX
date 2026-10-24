import Foundation

/// The gameplay clock is independent of when HealthKit becomes ready to collect samples.
nonisolated struct SessionElapsedClock: Codable, Equatable, Sendable {
    private(set) var runningStart: Date
    private(set) var pausedElapsed: TimeInterval?
    private(set) var revision: Int = 0
    private(set) var origin: String = "phone"

    var isPaused: Bool { pausedElapsed != nil }
    var encoded: Data? { try? JSONEncoder().encode(self) }

    init(start: Date) {
        runningStart = start
    }

    init?(data: Data?) {
        guard let data, let clock = try? JSONDecoder().decode(Self.self, from: data),
              clock.runningStart.timeIntervalSince1970.isFinite,
              clock.pausedElapsed.map({ $0.isFinite && $0 >= 0 }) ?? true,
              clock.revision >= 0, clock.revision < Int.max,
              ["phone", "watch"].contains(clock.origin) else { return nil }
        self = clock
    }

    func elapsed(at date: Date) -> TimeInterval {
        pausedElapsed ?? max(0, date.timeIntervalSince(runningStart))
    }

    mutating func setPaused(_ paused: Bool, at date: Date, origin: String) {
        guard paused != isPaused else { return }
        if paused {
            pausedElapsed = elapsed(at: date)
        } else {
            runningStart = date.addingTimeInterval(-(pausedElapsed ?? 0))
            pausedElapsed = nil
        }
        revision += 1
        self.origin = origin
    }

    /// A reply sent before a local pause must not undo it when it arrives later.
    func supersedes(_ other: Self) -> Bool {
        revision > other.revision || (revision == other.revision && origin > other.origin)
    }
}
