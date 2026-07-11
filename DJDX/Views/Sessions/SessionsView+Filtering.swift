import Foundation

extension IIDXCapturedPlay {
    func scoreRate(songCompactTitles: [String: IIDXSong]) -> Float? {
        guard let title = songTitle,
              let noteCount = songCompactTitles[title.compact]?.spNoteCount?.noteCount(for: level),
              noteCount > 0 else { return nil }
        return Float(exScore) / Float(noteCount * 2)
    }
}

extension SessionsView {

    var isSearching: Bool {
        !searchTerm.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var displayedPlays: [IIDXCapturedPlay] {
        sorted(filtered(latestPlays))
    }

    func filtered(_ plays: [IIDXCapturedPlay]) -> [IIDXCapturedPlay] {
        let searchTermTrimmed = searchTerm.lowercased().trimmingCharacters(in: .whitespaces)
        let difficultyRawValues = Set(difficultiesToShow.map(\.rawValue))
        let clearTypeRawValues = Set(clearTypesToShow.map(\.rawValue))
        let djLevelRawValues = Set(djLevelsToShow.map(\.rawValue))
        return plays.filter { play in
            if !searchTermTrimmed.isEmpty,
               !(play.songTitle ?? "").lowercased().contains(searchTermTrimmed) { return false }
            if play.level == .beginner && isBeginnerLevelHidden { return false }
            if !levelsToShow.isEmpty && !levelsToShow.contains(play.level) { return false }
            if !difficultiesToShow.isEmpty && !difficultyRawValues.contains(play.difficulty) { return false }
            if !clearTypesToShow.isEmpty && !clearTypeRawValues.contains(play.clearType) { return false }
            if !djLevelsToShow.isEmpty && !djLevelRawValues.contains(play.djLevel) { return false }
            return true
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    func sorted(_ plays: [IIDXCapturedPlay]) -> [IIDXCapturedPlay] {
        var plays = plays
        let isAscending = sortOrder == .ascending
        func title(_ play: IIDXCapturedPlay) -> String { play.songTitle ?? "" }

        switch sortMode {
        case .title:
            plays.sort { isAscending ? title($0) < title($1) : title($0) > title($1) }
        case .clearType:
            let order = IIDXClearType.sortedStrings
            plays.sort { lhs, rhs in
                let leftIndex = order.firstIndex(of: lhs.clearType)
                let rightIndex = order.firstIndex(of: rhs.clearType)
                if leftIndex == rightIndex { return title(lhs) < title(rhs) }
                guard let leftIndex, let rightIndex else { return leftIndex != nil }
                return isAscending ? leftIndex < rightIndex : leftIndex > rightIndex
            }
        case .djLevel:
            let order = IIDXDJLevel.sorted
            plays.sort { lhs, rhs in
                let leftIndex = order.firstIndex(of: IIDXDJLevel(rawValue: lhs.djLevel) ?? .none)
                let rightIndex = order.firstIndex(of: IIDXDJLevel(rawValue: rhs.djLevel) ?? .none)
                if leftIndex == rightIndex { return title(lhs) < title(rhs) }
                guard let leftIndex, let rightIndex else { return leftIndex != nil }
                return isAscending ? leftIndex < rightIndex : leftIndex > rightIndex
            }
        case .scoreRate:
            plays.sort { lhs, rhs in
                let leftRate = lhs.scoreRate(songCompactTitles: songCompactTitles) ?? 0.0
                let rightRate = rhs.scoreRate(songCompactTitles: songCompactTitles) ?? 0.0
                if leftRate == rightRate { return title(lhs) < title(rhs) }
                return isAscending ? leftRate < rightRate : leftRate > rightRate
            }
        case .score:
            plays.sort { lhs, rhs in
                if lhs.exScore == rhs.exScore { return title(lhs) < title(rhs) }
                return isAscending ? lhs.exScore < rhs.exScore : lhs.exScore > rhs.exScore
            }
        case .missCount:
            plays.sort { lhs, rhs in
                if lhs.miss == rhs.miss { return title(lhs) < title(rhs) }
                return isAscending ? lhs.miss < rhs.miss : lhs.miss > rhs.miss
            }
        case .difficulty:
            plays.sort { lhs, rhs in
                if lhs.difficulty == rhs.difficulty { return title(lhs) < title(rhs) }
                return isAscending ? lhs.difficulty < rhs.difficulty : lhs.difficulty > rhs.difficulty
            }
        case .lastPlayDate:
            plays.sort { isAscending ? $0.captureDate < $1.captureDate : $0.captureDate > $1.captureDate }
        }
        return plays
    }
}
