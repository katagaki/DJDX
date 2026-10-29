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

    func reloadProgress(playType: IIDXPlayType, iidxVersion: IIDXVersion, filters: FilterOptions? = nil) async {
        debugPrint("Calculating progress")
        let importGroups = await fetcher.importGroups(for: iidxVersion)
        var points: [IIDXProgressPoint] = []
        var previousRecords: [IIDXSongRecord]?
        for importGroup in importGroups {
            let records = await fetcher.songRecords(for: importGroup.id, playType: playType)
            guard !records.isEmpty else { continue }
            if let previousRecords {
                let computed = Self.computeNewEntries(
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
        withAnimation(.smooth.speed(2.0)) {
            self.progressPerImportGroup = points
        }
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
