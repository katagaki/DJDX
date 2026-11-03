import Foundation

extension IIDXChartProfile {

    static func hasRapidRepeats(notes: [IIDXChartNote], bpmChanges: [IIDXChartBPMChange],
                                scratchLanes: Set<Int>) -> Bool {
        let changes = bpmChanges.sorted { $0.time < $1.time }
        let changeTimes = changes.map(\.time)
        func beatLength(at time: Double) -> Double {
            guard !changes.isEmpty else { return 400.0 }
            let bpm = changes[max(lowerBound(changeTimes, time + 1.0) - 1, 0)].bpm
            return bpm > 0.0 ? 60000.0 / bpm : 400.0
        }
        let notesByLane = Dictionary(grouping: notes.indices.filter { !scratchLanes.contains(notes[$0].lane) }) {
            notes[$0].lane
        }
        var marked = Set<Int>()
        for indices in notesByLane.values {
            let sorted = indices.sorted { notes[$0].time < notes[$1].time }
            var chain: [Int] = []
            for index in sorted {
                guard let previous = chain.last else {
                    chain = [index]
                    continue
                }
                let previousNote = notes[previous]
                let gap = notes[index].time - (previousNote.endTime ?? previousNote.time)
                let beat = beatLength(at: previousNote.time)
                if gap <= 5.0 { continue }
                if gap <= min(beat * 0.26 + 1.0, 200.0) {
                    marked.formUnion([previous, index])
                }
                if gap <= min(beat * 0.51 + 1.0, 200.0) {
                    chain.append(index)
                } else {
                    if chain.count >= 3 { marked.formUnion(chain) }
                    chain = [index]
                }
            }
            if chain.count >= 3 { marked.formUnion(chain) }
        }
        return marked.count >= 100 && Double(marked.count) / Double(notes.count) >= 0.10
    }
}
