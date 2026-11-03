import Foundation

struct IIDXChartNote: Decodable, Sendable {
    let lane: Int
    let time: Double
    let type: String
}

struct IIDXChartBPMChange: Decodable, Sendable {
    let time: Double
    let bpm: Double
}

struct IIDXChartProfile: Codable, Sendable, Hashable {

    let traits: [IIDXChartTrait]

    private static let staminaBaselines: [Int: Double] = [
        1: 2.0, 2: 2.6, 3: 3.3, 4: 4.2, 5: 4.9, 6: 5.5,
        7: 6.5, 8: 7.3, 9: 8.3, 10: 10.0, 11: 11.6, 12: 15.3
    ]

    init(traits: [IIDXChartTrait]) {
        self.traits = traits
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    init(notes: [IIDXChartNote], bpmChanges: [IIDXChartBPMChange], playType: IIDXPlayType, level: Int) {
        let times = notes.map { $0.time / 1000.0 }.sorted()
        guard times.count >= 50, let first = times.first, let last = times.last, last - first >= 20.0 else {
            self.traits = []
            return
        }
        let duration = last - first
        let scratchLanes: Set<Int> = playType == .double ? [0, 8] : [0]

        let density2 = Self.densities(times, window: 2.0).map(\.value)
        let density5 = Self.densities(times, window: 5.0)
        let density10 = Self.densities(times, window: 10.0)
        let values10 = density10.map(\.value)

        var traits: [IIDXChartTrait] = []

        let peakPosition: Double
        if let peak = density10.max(by: { $0.value < $1.value }) {
            peakPosition = (peak.start + 5.0 - first) / duration
        } else {
            peakPosition = 0.0
        }
        let tailStart = first + duration * 0.85 - 5.0
        let tailPeak = density5.filter { $0.start >= tailStart }.map(\.value).max() ?? 0.0
        let headMedian = Self.median(density5.filter { $0.start < tailStart }.map(\.value))
        if headMedian > 0.0, tailPeak / headMedian >= 1.6, peakPosition >= 0.8 {
            traits.append(.backloaded)
        }

        let maxDensity10 = values10.max() ?? 0.0
        let median2 = Self.median(density2)
        if maxDensity10 > 0.0, median2 > 0.0,
           Self.median(values10) / maxDensity10 <= 0.68,
           (density2.max() ?? 0.0) / median2 >= 1.7,
           peakPosition < 0.8 {
            traits.append(.burst)
        }

        if playType == .single, duration >= 60.0, let baseline = Self.staminaBaselines[level],
           Double(times.count) / duration >= baseline * 1.13 {
            traits.append(.stamina)
        }

        var onsets: [Int: Set<Int>] = [:]
        for note in notes where !scratchLanes.contains(note.lane) {
            onsets[Int(note.time.rounded()), default: []].insert(note.lane)
        }
        let patterns = onsets.keys.sorted().compactMap { onsets[$0] }
        if patterns.count >= 50 {
            var structured = 0
            for index in 2..<patterns.count {
                let previous2 = patterns[index - 2]
                let previous1 = patterns[index - 1]
                let current = patterns[index]
                if current == previous1 || current == previous2 {
                    structured += 1
                } else if current.count == 1, previous1.count == 1, previous2.count == 1,
                          let lane0 = previous2.first, let lane1 = previous1.first, let lane2 = current.first,
                          lane2 - lane1 == lane1 - lane0, abs(lane2 - lane1) == 1 {
                    structured += 1
                }
            }
            if Double(structured) / Double(patterns.count - 2) <= 0.10 {
                traits.append(.chaotic)
            }
        }

        let noteCount = Double(notes.count)
        if Double(notes.filter { scratchLanes.contains($0.lane) }.count) / noteCount >= 0.08 {
            traits.append(.scratch)
        }
        if Double(notes.filter { $0.type != "normal" }.count) / noteCount >= 0.02 {
            traits.append(.charge)
        }

        let sortedChanges = bpmChanges.sorted { $0.time < $1.time }
        var sustainedBPMs: [Double] = []
        for (index, change) in sortedChanges.enumerated() where change.bpm > 0.0 {
            let end = index + 1 < sortedChanges.count ? sortedChanges[index + 1].time : last * 1000.0
            if end - change.time >= 2000.0 {
                sustainedBPMs.append(change.bpm)
            }
        }
        if let minBPM = sustainedBPMs.min(), let maxBPM = sustainedBPMs.max(), maxBPM / minBPM >= 1.2 {
            traits.append(.soflan)
        }

        self.traits = traits
    }

    private static func densities(_ times: [Double], window: Double) -> [(start: Double, value: Double)] {
        guard let first = times.first, let last = times.last else { return [] }
        var results: [(start: Double, value: Double)] = []
        var lower = 0
        var upper = 0
        var start = first
        while start + window <= last + 1e-9 {
            while lower < times.count, times[lower] < start { lower += 1 }
            while upper < times.count, times[upper] < start + window { upper += 1 }
            results.append((start: start, value: Double(upper - lower) / window))
            start += 0.5
        }
        return results
    }

    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.0 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count % 2 == 0 ? (sorted[middle - 1] + sorted[middle]) / 2.0 : sorted[middle]
    }
}
