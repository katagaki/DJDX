import SwiftUI

struct IIDXDJLevelSuggestion: Identifiable {
    let id = UUID()
    let songTitle: String
    let level: IIDXLevel
    let difficulty: Int
    let score: Int
    let currentDJLevel: String
    let targetDJLevel: String
    let targetScore: Int

    var pointsNeeded: Int { targetScore - score }
}

struct IIDXClearLampSuggestion: Identifiable {
    let id = UUID()
    let songTitle: String
    let level: IIDXLevel
    let difficulty: Int
    let score: Int
    let clearType: String
}

extension IIDXLevel {
    var chartName: String {
        switch self {
        case .beginner: return "BEGINNER"
        case .normal: return "NORMAL"
        case .hyper: return "HYPER"
        case .another: return "ANOTHER"
        case .leggendaria: return "LEGGENDARIA"
        case .all, .unknown: return ""
        }
    }

    var chartColor: Color {
        switch self {
        case .beginner: return .green
        case .normal: return .blue
        case .hyper: return .orange
        case .another: return .red
        case .leggendaria: return .purple
        case .all, .unknown: return .primary
        }
    }
}

extension AnalyticsModel {

    nonisolated static let djLevelThresholds: [IIDXDJLevel] = [.djE, .djD, .djC, .djB, .djA, .djAA, .djAAA]

    nonisolated static let suggestionTargetClearTypes: [IIDXClearType] = [
        .assistClear, .easyClear, .clear, .hardClear, .exHardClear, .fullComboClear
    ]

    nonisolated static func clearType(before target: IIDXClearType) -> IIDXClearType? {
        guard let index = IIDXClearType.ascending.firstIndex(of: target), index > 0 else { return nil }
        return IIDXClearType.ascending[index - 1]
    }

    func clearLampSuggestions(for target: IIDXClearType) -> [IIDXClearLampSuggestion] {
        guard let previous = Self.clearType(before: target) else { return [] }
        return clearLampSuggestionCandidates.filter { $0.clearType == previous.rawValue }
    }

    func reloadSuggestions(playType: IIDXPlayType, iidxVersion: IIDXVersion, filters: FilterOptions? = nil) async {
        guard let latestGroup = await fetcher.importGroups(for: iidxVersion).last else {
            withAnimation(.smooth.speed(2.0)) {
                djLevelSuggestions = []
                clearLampSuggestionCandidates = []
            }
            return
        }
        async let recordsTask = fetcher.songRecords(for: latestGroup.id, playType: playType)
        async let songsTask = fetcher.songCompactTitles()
        let records = await recordsTask
        let songs = await songsTask
        let computed = Self.computeSuggestions(records: records, songs: songs, playType: playType, filters: filters)
        withAnimation(.smooth.speed(2.0)) {
            djLevelSuggestions = computed.djLevels
            clearLampSuggestionCandidates = computed.clearLamps
        }
    }

    nonisolated static func computeSuggestions(
        records: [IIDXSongRecord],
        songs: [String: IIDXSong],
        playType: IIDXPlayType,
        filters: FilterOptions?
    ) -> (djLevels: [IIDXDJLevelSuggestion], clearLamps: [IIDXClearLampSuggestion]) {
        var djLevels: [IIDXDJLevelSuggestion] = []
        var clearLamps: [IIDXClearLampSuggestion] = []
        for record in records {
            if let versions = filters?.versions, !versions.isEmpty, !versions.contains(record.version) {
                continue
            }
            let song = songs[record.titleCompact()]
            let noteCounts = playType == .single ? song?.spNoteCount : song?.dpNoteCount
            for score in record.scores() where score.level != .unknown {
                if let filters, !Self.score(score, level: score.level, matches: filters) { continue }
                if score.clearType != IIDXClearType.noPlay.rawValue {
                    clearLamps.append(IIDXClearLampSuggestion(
                        songTitle: record.title, level: score.level, difficulty: score.difficulty,
                        score: score.score, clearType: score.clearType
                    ))
                }
                guard score.score > 0, let noteCount = noteCounts?.noteCount(for: score.level),
                      noteCount > 0 else { continue }
                let maxScore = noteCount * 2
                guard let targetIndex = djLevelThresholds.indices.first(where: { index in
                    threshold(index: index, maxScore: maxScore) > score.score
                }) else { continue }
                let currentDJLevel = targetIndex > 0 ? djLevelThresholds[targetIndex - 1].rawValue : "F"
                djLevels.append(IIDXDJLevelSuggestion(
                    songTitle: record.title, level: score.level, difficulty: score.difficulty,
                    score: score.score, currentDJLevel: currentDJLevel,
                    targetDJLevel: djLevelThresholds[targetIndex].rawValue,
                    targetScore: threshold(index: targetIndex, maxScore: maxScore)
                ))
            }
        }
        djLevels.sort {
            if $0.pointsNeeded != $1.pointsNeeded { return $0.pointsNeeded < $1.pointsNeeded }
            return $0.difficulty > $1.difficulty
        }
        clearLamps.sort {
            if $0.difficulty != $1.difficulty { return $0.difficulty > $1.difficulty }
            return $0.score > $1.score
        }
        return (djLevels, clearLamps)
    }

    nonisolated static func threshold(index: Int, maxScore: Int) -> Int {
        (maxScore * (index + 2) + 8) / 9
    }
}
