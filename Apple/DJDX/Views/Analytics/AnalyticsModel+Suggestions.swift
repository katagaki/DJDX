import SwiftUI

struct IIDXDJLevelSuggestion: Identifiable {
    let id = UUID()
    let songRecord: IIDXSongRecord
    let score: IIDXLevelScore
    let scoreRate: Float?
    let currentDJLevel: String
    let targetDJLevel: String
    let targetScore: Int

    var level: IIDXLevel { score.level }
    var difficulty: Int { score.difficulty }
    var pointsNeeded: Int { targetScore - score.score }
}

struct IIDXChartSuggestion: Identifiable {
    let id = UUID()
    let songRecord: IIDXSongRecord
    let score: IIDXLevelScore
    let scoreRate: Float?

    var level: IIDXLevel { score.level }
    var difficulty: Int { score.difficulty }
    var clearType: String { score.clearType }
}

struct IIDXSuggestionSet {
    let djLevels: [IIDXDJLevelSuggestion]
    let clearLamps: [IIDXChartSuggestion]
    let longUnplayed: [IIDXChartSuggestion]
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

    func clearLampSuggestions(for target: IIDXClearType) -> [IIDXChartSuggestion] {
        guard let previous = Self.clearType(before: target) else { return [] }
        return clearLampSuggestionCandidates.filter { $0.clearType == previous.rawValue }
    }

    nonisolated static func computeSuggestions(
        records: [IIDXSongRecord],
        songs: [String: IIDXSong],
        playType: IIDXPlayType,
        filters: FilterOptions?
    ) -> IIDXSuggestionSet {
        var djLevels: [IIDXDJLevelSuggestion] = []
        var clearLamps: [IIDXChartSuggestion] = []
        for record in records {
            if let versions = filters?.versions, !versions.isEmpty, !versions.contains(record.version) {
                continue
            }
            let song = songs[record.titleCompact()]
            let noteCounts = playType == .single ? song?.spNoteCount : song?.dpNoteCount
            for score in record.scores() where score.level != .unknown {
                if let filters, !Self.score(score, level: score.level, matches: filters) { continue }
                let noteCount = noteCounts?.noteCount(for: score.level) ?? 0
                let scoreRate: Float? = noteCount > 0 ? Float(score.score) / Float(noteCount * 2) : nil
                if score.clearType != IIDXClearType.noPlay.rawValue {
                    clearLamps.append(IIDXChartSuggestion(songRecord: record, score: score, scoreRate: scoreRate))
                }
                guard score.score > 0, noteCount > 0 else { continue }
                let maxScore = noteCount * 2
                guard let targetIndex = djLevelThresholds.indices.first(where: { index in
                    threshold(index: index, maxScore: maxScore) > score.score
                }) else { continue }
                let currentDJLevel = targetIndex > 0 ? djLevelThresholds[targetIndex - 1].rawValue : "F"
                djLevels.append(IIDXDJLevelSuggestion(
                    songRecord: record, score: score, scoreRate: scoreRate,
                    currentDJLevel: currentDJLevel,
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
            return $0.score.score > $1.score.score
        }
        let longUnplayed = clearLamps
            .filter { $0.songRecord.lastPlayDate > .distantPast }
            .sorted {
                if $0.songRecord.lastPlayDate != $1.songRecord.lastPlayDate {
                    return $0.songRecord.lastPlayDate < $1.songRecord.lastPlayDate
                }
                return $0.difficulty > $1.difficulty
            }
        return IIDXSuggestionSet(djLevels: djLevels, clearLamps: clearLamps, longUnplayed: longUnplayed)
    }

    nonisolated static func threshold(index: Int, maxScore: Int) -> Int {
        (maxScore * (index + 2) + 8) / 9
    }
}
