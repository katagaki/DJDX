import OrderedCollections
import SwiftUI

extension AnalyticsModel {

    func reloadFromLastSession(store: IIDXSessionStore, playType: IIDXPlayType) {
        store.loadSessions()
        let sessions = store.sessions.sorted { $0.startDate < $1.startDate }

        guard let lastSession = sessions.last else {
            withAnimation(.smooth.speed(2.0)) {
                clearSessionData()
            }
            return
        }

        let lastPlays = Self.latestPlaysPerChart(
            validPlays(store.plays(for: lastSession), playType: playType)
        )
        let baseline = Self.latestPlaysPerChart(
            sessions.dropLast().flatMap { validPlays(store.plays(for: $0), playType: playType) }
        )
        let cumulativePlays = Self.latestPlaysPerChart(baseline + lastPlays)

        let trends = cumulativeTrends(store: store, playType: playType, sessions: sessions)

        let computed = Self.computeNewEntries(
            latestRecords: Self.mergedSongRecords(lastPlays),
            previousRecords: Self.mergedSongRecords(baseline)
        )

        withAnimation(.smooth.speed(2.0)) {
            clearTypePerDifficulty = buildOrderedClearType(from: Self.clearTypeCounts(of: cumulativePlays))
            djLevelPerDifficulty = convertToEnumKeyed(
                buildOrderedDJLevel(from: Self.djLevelCounts(of: cumulativePlays))
            )
            clearTypePerImportGroup = trends.clearType
            djLevelPerImportGroup = trends.djLevel
            newClears = computed.clears["CLEAR"]!
            newEasyClears = computed.clears["EASY CLEAR"]!
            newAssistClears = computed.clears["ASSIST CLEAR"]!
            newFullComboClears = computed.clears["FULLCOMBO CLEAR"]!
            newHardClears = computed.clears["HARD CLEAR"]!
            newExHardClears = computed.clears["EX HARD CLEAR"]!
            newFailed = computed.clears["FAILED"]!
            newHighScores = computed.highScores
            newAAA = computed.djLevels["AAA"]!
            newAA = computed.djLevels["AA"]!
            newA = computed.djLevels["A"]!
        }
    }

    private func cumulativeTrends(
        store: IIDXSessionStore,
        playType: IIDXPlayType,
        sessions: [IIDXPlaySession]
    ) -> (
        clearType: [Date: [Int: OrderedDictionary<String, Int>]],
        djLevel: [Date: [Int: OrderedDictionary<String, Int>]]
    ) {
        var clearType: [Date: [Int: OrderedDictionary<String, Int>]] = [:]
        var djLevel: [Date: [Int: OrderedDictionary<String, Int>]] = [:]
        var accumulatedPlays: [IIDXCapturedPlay] = []
        for session in sessions {
            let plays = validPlays(store.plays(for: session), playType: playType)
            guard !plays.isEmpty else { continue }
            accumulatedPlays = Self.latestPlaysPerChart(accumulatedPlays + plays)
            clearType[session.startDate] = buildOrderedClearType(
                from: Self.clearTypeCounts(of: accumulatedPlays)
            )
            djLevel[session.startDate] = buildOrderedDJLevel(
                from: Self.djLevelCounts(of: accumulatedPlays)
            )
        }
        return (clearType, djLevel)
    }

    private func clearSessionData() {
        clearTypePerDifficulty.removeAll()
        djLevelPerDifficulty.removeAll()
        clearTypePerImportGroup.removeAll()
        djLevelPerImportGroup.removeAll()
        newClears = []
        newEasyClears = []
        newAssistClears = []
        newFullComboClears = []
        newHardClears = []
        newExHardClears = []
        newFailed = []
        newHighScores = []
        newAAA = []
        newAA = []
        newA = []
    }

    private func validPlays(_ plays: [IIDXCapturedPlay], playType: IIDXPlayType) -> [IIDXCapturedPlay] {
        plays.filter { play in
            (play.state == .done || play.state == .needsReview) &&
            play.playType == playType &&
            play.difficulty > 0 &&
            play.songTitle?.isEmpty == false
        }
    }

    nonisolated static func latestPlaysPerChart(_ plays: [IIDXCapturedPlay]) -> [IIDXCapturedPlay] {
        var latest: [String: IIDXCapturedPlay] = [:]
        for play in plays {
            let key = play.chartKey()
            if let existing = latest[key], existing.captureDate >= play.captureDate { continue }
            latest[key] = play
        }
        return latest.values.sorted { $0.captureDate > $1.captureDate }
    }

    nonisolated static func mergedSongRecords(_ plays: [IIDXCapturedPlay]) -> [IIDXSongRecord] {
        var records: [String: IIDXSongRecord] = [:]
        for play in plays {
            let key = (play.songTitle ?? "").compact
            if let record = records[key] {
                let score = play.levelScore()
                switch play.level {
                case .beginner: record.beginnerScore = score
                case .normal: record.normalScore = score
                case .hyper: record.hyperScore = score
                case .another: record.anotherScore = score
                case .leggendaria: record.leggendariaScore = score
                default: break
                }
                record.lastPlayDate = max(record.lastPlayDate, play.captureDate)
            } else {
                records[key] = play.asSongRecord()
            }
        }
        return records.values.sorted { $0.lastPlayDate < $1.lastPlayDate }
    }

    nonisolated static func clearTypeCounts(of plays: [IIDXCapturedPlay]) -> [Int: [String: Int]] {
        plays.reduce(into: [:]) { counts, play in
            counts[play.difficulty, default: [:]][play.clearType, default: 0] += 1
        }
    }

    nonisolated static func djLevelCounts(of plays: [IIDXCapturedPlay]) -> [Int: [String: Int]] {
        plays.reduce(into: [:]) { counts, play in
            counts[play.difficulty, default: [:]][play.djLevel, default: 0] += 1
        }
    }
}
