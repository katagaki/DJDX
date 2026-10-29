import SwiftUI

struct IIDXProgressPoint: Identifiable, Hashable {
    let date: Date
    let newClears: Int
    let newHighScores: Int

    var id: Date { date }
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
                    newClears: computed.clearLamps.count,
                    newHighScores: computed.scoreUpdates.count
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
                newClears: computed.clearLamps.count,
                newHighScores: computed.scoreUpdates.count
            ))
            baseline = Self.latestPlaysPerChart(baseline + plays)
        }
        return points
    }
}
