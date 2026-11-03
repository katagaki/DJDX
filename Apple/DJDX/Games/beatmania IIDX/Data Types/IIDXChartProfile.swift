import Foundation

struct IIDXChartNote: Decodable, Sendable {
    let lane: Int
    let time: Double
    let type: String
    let endTime: Double?
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

    init(notes: [IIDXChartNote], bpmChanges: [IIDXChartBPMChange], playType: IIDXPlayType, level: Int) {
        let times = notes.map { $0.time / 1000.0 }.sorted()
        guard times.count >= 50, let first = times.first, let last = times.last, last - first >= 20.0 else {
            self.traits = []
            return
        }
        let scratchLanes: Set<Int> = playType == .double ? [0, 8] : [0]
        var traits: [IIDXChartTrait] = []
        traits += Self.densityTraits(times: times, first: first, last: last, playType: playType, level: level)
        if Self.isChaotic(notes: notes, scratchLanes: scratchLanes) {
            traits.append(.chaotic)
        }
        traits += Self.scratchComboTraits(notes: notes, playType: playType)
        if Self.isChargeCombo(notes: notes, scratchLanes: scratchLanes) {
            traits.append(.chargeCombo)
        }
        traits += Self.soflanTraits(bpmChanges: bpmChanges, noteTimes: notes.map(\.time).sorted())
        self.traits = traits
    }

    // MARK: Density

    private static func densityTraits(times: [Double], first: Double, last: Double,
                                      playType: IIDXPlayType, level: Int) -> [IIDXChartTrait] {
        let duration = last - first
        let density2 = densities(times, window: 2.0).map(\.value)
        let density5 = densities(times, window: 5.0)
        let density10 = densities(times, window: 10.0)
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
        let headMedian = median(density5.filter { $0.start < tailStart }.map(\.value))
        if headMedian > 0.0, tailPeak / headMedian >= 1.6, peakPosition >= 0.8 {
            traits.append(.backloaded)
        }

        let maxDensity10 = values10.max() ?? 0.0
        let median2 = median(density2)
        if maxDensity10 > 0.0, median2 > 0.0,
           median(values10) / maxDensity10 <= 0.68,
           (density2.max() ?? 0.0) / median2 >= 1.7,
           peakPosition < 0.8 {
            traits.append(.burst)
        }

        if playType == .single, duration >= 60.0, let baseline = staminaBaselines[level],
           Double(times.count) / duration >= baseline * 1.13 {
            traits.append(.stamina)
        }
        return traits
    }

    // MARK: Patterns

    private static func isChaotic(notes: [IIDXChartNote], scratchLanes: Set<Int>) -> Bool {
        var onsets: [Int: Set<Int>] = [:]
        for note in notes where !scratchLanes.contains(note.lane) {
            onsets[Int(note.time.rounded()), default: []].insert(note.lane)
        }
        let patterns = onsets.keys.sorted().compactMap { onsets[$0] }
        guard patterns.count >= 50 else { return false }
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
        return Double(structured) / Double(patterns.count - 2) <= 0.10
    }

    private static func scratchComboTraits(notes: [IIDXChartNote], playType: IIDXPlayType) -> [IIDXChartTrait] {
        let noteCount = Double(notes.count)
        func qualifies(_ hits: Int) -> Bool {
            hits >= 100 && Double(hits) / noteCount >= 0.09
        }
        switch playType {
        case .double:
            let hits = scratchComboHits(notes: notes, scratchLane: 0, keyLanes: [1, 2, 3]) +
                scratchComboHits(notes: notes, scratchLane: 8, keyLanes: [13, 14, 15])
            return qualifies(hits) ? [.scratchCombo] : []
        case .single:
            let side1P = qualifies(scratchComboHits(notes: notes, scratchLane: 0, keyLanes: [1, 2, 3]))
            let side2P = qualifies(scratchComboHits(notes: notes, scratchLane: 0, keyLanes: [5, 6, 7]))
            return side1P || side2P ? [.scratchCombo] : []
        }
    }

    private static func scratchComboHits(notes: [IIDXChartNote], scratchLane: Int, keyLanes: Set<Int>) -> Int {
        let scratches = notes.filter { $0.lane == scratchLane }.map(\.time)
        let keys = notes.filter { keyLanes.contains($0.lane) }.map(\.time).sorted()
        guard !keys.isEmpty else { return 0 }
        return scratches.filter { time in
            let index = lowerBound(keys, time - 110.0)
            return index < keys.count && keys[index] <= time + 110.0
        }.count
    }

    private static func isChargeCombo(notes: [IIDXChartNote], scratchLanes: Set<Int>) -> Bool {
        let holds = notes.compactMap { note -> Hold? in
            guard note.type != "normal", let end = note.endTime else { return nil }
            return Hold(lane: note.lane, start: note.time + 30.0, end: end - 30.0)
        }
        guard !holds.isEmpty else { return false }
        let pressedDuringHold = notes.filter { note in
            note.type == "normal" && !scratchLanes.contains(note.lane) && holds.contains { hold in
                hold.lane != note.lane && hold.start < note.time && note.time < hold.end
            }
        }.count
        return pressedDuringHold >= 60 && Double(pressedDuringHold) / Double(notes.count) >= 0.06
    }

    private struct Hold {
        let lane: Int
        let start: Double
        let end: Double
    }

    // MARK: Soflan

    private struct BPMSegment {
        let bpm: Double
        let duration: Double
        let noteCount: Int
    }

    private static func soflanTraits(bpmChanges: [IIDXChartBPMChange], noteTimes: [Double]) -> [IIDXChartTrait] {
        guard let lastNote = noteTimes.last else { return [] }
        let changes = bpmChanges.sorted { $0.time < $1.time }
        var segments: [BPMSegment] = []
        for (index, change) in changes.enumerated() {
            let end = index + 1 < changes.count ? changes[index + 1].time : lastNote
            guard change.bpm > 0.0, end > change.time else { continue }
            let noteCount = lowerBound(noteTimes, end) - lowerBound(noteTimes, change.time)
            segments.append(BPMSegment(bpm: change.bpm, duration: end - change.time, noteCount: noteCount))
        }
        guard segments.count >= 2 else { return [] }
        var traits: [IIDXChartTrait] = []
        if hasGradualSoflan(segments) {
            traits.append(.gradualSoflan)
        }
        let hasSuddenSoflan = zip(segments, segments.dropFirst()).contains { previous, next in
            max(previous.bpm, next.bpm) / min(previous.bpm, next.bpm) >= 1.3 &&
                previous.noteCount >= 3 && next.noteCount >= 3
        }
        if hasSuddenSoflan {
            traits.append(.suddenSoflan)
        }
        return traits
    }

    private static func hasGradualSoflan(_ segments: [BPMSegment]) -> Bool {
        var start = 0
        while start < segments.count - 1 {
            var end = start
            var direction = 0.0
            while end + 1 < segments.count {
                let ratio = segments[end + 1].bpm / segments[end].bpm
                let step = max(ratio, 1.0 / ratio)
                let stepDirection: Double = ratio > 1.0 ? 1.0 : (ratio < 1.0 ? -1.0 : 0.0)
                if stepDirection == 0.0 || step > 1.3 || (direction != 0.0 && stepDirection != direction) ||
                    (end > start && segments[end].duration > 4000.0) {
                    break
                }
                direction = stepDirection
                end += 1
            }
            if end - start >= 3 {
                let total = max(segments[start].bpm, segments[end].bpm) / min(segments[start].bpm, segments[end].bpm)
                let noteCount = segments[(start + 1)...end].reduce(0) { $0 + $1.noteCount }
                if total >= 1.2 && noteCount >= 8 {
                    return true
                }
            }
            start = max(end, start + 1)
        }
        return false
    }

    // MARK: Helpers

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

    private static func lowerBound(_ values: [Double], _ target: Double) -> Int {
        var low = 0
        var high = values.count
        while low < high {
            let middle = (low + high) / 2
            if values[middle] < target {
                low = middle + 1
            } else {
                high = middle
            }
        }
        return low
    }

    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0.0 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count % 2 == 0 ? (sorted[middle - 1] + sorted[middle]) / 2.0 : sorted[middle]
    }
}
