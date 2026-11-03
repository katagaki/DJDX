import Foundation

extension IIDXChartProfile {

    struct BPMSegment {
        let bpm: Double
        let duration: Double
        let noteCount: Int
    }

    static func soflanTraits(bpmChanges: [IIDXChartBPMChange], noteTimes: [Double]) -> [IIDXChartTrait] {
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

    static func hasGradualSoflan(_ segments: [BPMSegment]) -> Bool {
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
}
