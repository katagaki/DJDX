import SwiftUI

struct IIDXProgressPoint: Identifiable, Hashable {
    let date: Date
    let newClears: [String: Int]
    let newHighScores: [String: Int]

    var id: Date { date }

    init(date: Date, newClears: [NewClearEntry], newHighScores: [NewHighScoreEntry]) {
        self.date = date
        self.newClears = newClears.reduce(into: [:]) { $0[$1.score.clearType, default: 0] += 1 }
        self.newHighScores = newHighScores.reduce(into: [:]) { $0[$1.score.djLevel, default: 0] += 1 }
    }

    func count(for series: String, kind: IIDXProgressKind) -> Int {
        switch kind {
        case .clears: newClears[series] ?? 0
        case .highScores: newHighScores[series] ?? 0
        }
    }
}

extension AnalyticsModel {

    nonisolated static func loadProgress(
        importGroups: [ImportGroup], playType: IIDXPlayType, filters: FilterOptions?
    ) async -> [IIDXProgressPoint] {
        guard importGroups.count >= 2 else { return [] }
        let chunkCount = max(1, min(ProcessInfo.processInfo.activeProcessorCount, importGroups.count / 8))
        let chunkSize = (importGroups.count + chunkCount - 1) / chunkCount
        let ranges = stride(from: 0, to: importGroups.count, by: chunkSize).map {
            $0..<min($0 + chunkSize, importGroups.count)
        }
        return await withTaskGroup(of: (Int, [IIDXProgressPoint]).self) { group in
            for (index, range) in ranges.enumerated() {
                group.addTask {
                    (index, await progressPoints(
                        in: range, importGroups: importGroups, playType: playType, filters: filters
                    ))
                }
            }
            var chunks: [[IIDXProgressPoint]] = Array(repeating: [], count: ranges.count)
            for await (index, points) in group {
                chunks[index] = points
            }
            return chunks.flatMap { $0 }
        }
    }

    nonisolated static func progressPoints(
        in range: Range<Int>, importGroups: [ImportGroup], playType: IIDXPlayType, filters: FilterOptions?
    ) async -> [IIDXProgressPoint] {
        let reader = IIDXReader()
        var previousRecords: [IIDXSongRecord]?
        var baselineIndex = range.lowerBound - 1
        while previousRecords == nil, baselineIndex >= 0 {
            let records = await reader.songRecords(for: importGroups[baselineIndex].id, playType: playType)
            if !records.isEmpty { previousRecords = records }
            baselineIndex -= 1
        }
        var points: [IIDXProgressPoint] = []
        for importGroup in importGroups[range] {
            let records = await reader.songRecords(for: importGroup.id, playType: playType)
            guard !records.isEmpty else { continue }
            if let previousRecords {
                let computed = computeNewEntries(
                    latestRecords: records, previousRecords: previousRecords, filters: filters
                )
                points.append(IIDXProgressPoint(
                    date: importGroup.importDate,
                    newClears: computed.clearLamps,
                    newHighScores: computed.scoreUpdates
                ))
            }
            previousRecords = records
        }
        return points
    }

    func sessionProgress(
        store: IIDXSessionStore,
        playType: IIDXPlayType,
        sessions: [IIDXPlaySession]
    ) -> [IIDXProgressPoint] {
        var points: [IIDXProgressPoint] = []
        var baseline: [IIDXCapturedPlay] = []
        for session in sessions {
            let plays = Self.latestPlaysPerChart(validPlays(store.plays(for: session), playType: playType))
            guard !plays.isEmpty else { continue }
            let computed = Self.computeNewEntries(
                latestRecords: Self.mergedSongRecords(plays),
                previousRecords: Self.mergedSongRecords(baseline)
            )
            points.append(IIDXProgressPoint(
                date: session.startDate,
                newClears: computed.clearLamps,
                newHighScores: computed.scoreUpdates
            ))
            baseline = Self.latestPlaysPerChart(baseline + plays)
        }
        return points
    }
}
