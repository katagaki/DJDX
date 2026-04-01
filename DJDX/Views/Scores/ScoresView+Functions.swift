//
//  ScoresView+Functions.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/10/06.
//

import Foundation
import SwiftUI

extension ScoresView {

    func reloadDisplay() {
        withAnimation(.smooth.speed(2.0)) {
            dataState = .loading
        } completion: {
            Task.detached {
                let songRecords = await actor.songRecords(
                    on: playDataDate,
                    filters: FilterOptions(playType: playTypeToShow,
                                           onlyPlayDataWithScores: isShowingOnlyPlayDataWithScores,
                                           levels: levelsToShow,
                                           difficulties: difficultiesToShow,
                                           clearTypes: clearTypesToShow,
                                           djLevels: djLevelsToShow,
                                           versions: versionsToShow),
                    sortOptions: SortOptions(mode: sortMode, order: sortOrder)
                )
                let songCompactTitles = await actor.songCompactTitles()
                let songNoteCounts = await actor.songNoteCounts

                await MainActor.run {
                    withAnimation(.smooth.speed(2.0)) {
                        if let songRecords {
                            // Calculate clear rates
                            let noteCounts: [String: IIDXNoteCount] = songCompactTitles
                                .compactMapValues { $0.spNoteCount }

                            let songRecordClearRates: [IIDXSongRecord: [IIDXLevel: Float]] = songRecords
                                .reduce(into: [:], { partialResult, songRecord in
                                    let song = noteCounts[songRecord.titleCompact()]
                                    if let song {
                                        let scores: [IIDXLevelScore] = songRecord.scores()
                                        let scoreRates = scores.reduce(
                                            into: [:] as [IIDXLevel: Float]
                                        ) { partialResult, score in
                                            if let noteCount = song.noteCount(for: score.level) {
                                                partialResult[score.level] = Float(score.score) / Float(noteCount * 2)
                                            }
                                        }
                                        partialResult[songRecord] = scoreRates
                                    }
                                })

                            self.songRecordClearRates = songRecordClearRates
                            self.songRecords = songRecords
                        } else {
                            self.songRecordClearRates = [:]
                            self.songRecords = nil
                        }

                        self.songCompactTitles = songCompactTitles
                        self.songNoteCounts = noteCounts

                        dataState = .presenting
                    }
                }
            }
        }
    }

    private var noteCounts: [String: IIDXNoteCount] {
        songCompactTitles.compactMapValues { $0.spNoteCount }
    }

    func filterSongRecords() {
        guard let songRecords else {
            searchResults = nil
            return
        }
        let searchTermTrimmed = searchTerm.lowercased().trimmingCharacters(in: .whitespaces)
        if !searchTermTrimmed.isEmpty && searchTermTrimmed.count >= 1 {
            searchResults = songRecords.filter({ songRecord in
                songRecord.title.lowercased().contains(searchTermTrimmed) ||
                songRecord.artist.lowercased().contains(searchTermTrimmed)
            })
        } else {
            searchResults = nil
        }
    }

    struct SongLevelEntry {
        let songRecord: IIDXSongRecord
        let level: IIDXLevel
        let score: IIDXLevelScore
        var id: String { "\(songRecord.title)_\(level.rawValue)" }
    }

    func levelEntries(from records: [IIDXSongRecord]) -> [SongLevelEntry] {
        let difficultyRawValues = Set(difficultiesToShow.map(\.rawValue))
        var entries = records.flatMap { record in
            Self.allLevels.compactMap { level, keyPath in
                let score = record[keyPath: keyPath]
                guard score.difficulty > 0 else { return nil }
                if level == .beginner && isBeginnerLevelHidden { return nil }
                if !levelsToShow.isEmpty && !levelsToShow.contains(level) { return nil }
                if !difficultiesToShow.isEmpty && !difficultyRawValues.contains(score.difficulty) { return nil }
                if !clearTypesToShow.isEmpty &&
                    !clearTypesToShow.contains(where: { $0.rawValue == score.clearType }) { return nil }
                if !djLevelsToShow.isEmpty &&
                    !djLevelsToShow.contains(where: { $0.rawValue == score.djLevel }) { return nil }
                return SongLevelEntry(songRecord: record, level: level, score: score)
            }
        }

        let isAscending = sortOrder == .ascending
        switch sortMode {
        case .title:
            entries.sort { isAscending ? $0.songRecord.title < $1.songRecord.title
                : $0.songRecord.title > $1.songRecord.title }
        case .clearType:
            let order = IIDXClearType.sortedStrings
            entries.sort { lhs, rhs in
                let li = order.firstIndex(of: lhs.score.clearType)
                let ri = order.firstIndex(of: rhs.score.clearType)
                if li == ri { return lhs.songRecord.title < rhs.songRecord.title }
                guard let li, let ri else { return li != nil }
                return isAscending ? li < ri : li > ri
            }
        case .djLevel:
            let order = IIDXDJLevel.sorted
            entries.sort { lhs, rhs in
                let li = order.firstIndex(of: IIDXDJLevel(rawValue: lhs.score.djLevel) ?? .none)
                let ri = order.firstIndex(of: IIDXDJLevel(rawValue: rhs.score.djLevel) ?? .none)
                if li == ri { return lhs.songRecord.title < rhs.songRecord.title }
                guard let li, let ri else { return li != nil }
                return isAscending ? li < ri : li > ri
            }
        case .scoreRate:
            entries.sort { lhs, rhs in
                let lr = songRecordClearRates[lhs.songRecord]?[lhs.level] ?? 0
                let rr = songRecordClearRates[rhs.songRecord]?[rhs.level] ?? 0
                if lr == rr { return lhs.songRecord.title < rhs.songRecord.title }
                return isAscending ? lr < rr : lr > rr
            }
        case .score:
            entries.sort { lhs, rhs in
                if lhs.score.score == rhs.score.score { return lhs.songRecord.title < rhs.songRecord.title }
                return isAscending ? lhs.score.score < rhs.score.score
                    : lhs.score.score > rhs.score.score
            }
        case .missCount:
            entries.sort { lhs, rhs in
                if lhs.score.missCount == rhs.score.missCount { return lhs.songRecord.title < rhs.songRecord.title }
                return isAscending ? lhs.score.missCount < rhs.score.missCount
                    : lhs.score.missCount > rhs.score.missCount
            }
        case .difficulty:
            entries.sort { lhs, rhs in
                if lhs.score.difficulty == rhs.score.difficulty { return lhs.songRecord.title < rhs.songRecord.title }
                return isAscending ? lhs.score.difficulty < rhs.score.difficulty
                    : lhs.score.difficulty > rhs.score.difficulty
            }
        case .lastPlayDate:
            entries.sort { isAscending ? $0.songRecord.lastPlayDate < $1.songRecord.lastPlayDate
                : $0.songRecord.lastPlayDate > $1.songRecord.lastPlayDate }
        }

        return entries
    }

    func noteCount(for songRecord: IIDXSongRecord, of level: IIDXLevel) -> Int? {
        let compactTitle = songRecord.titleCompact()
        let keyPath: KeyPath<IIDXNoteCount, Int?>?
        switch level {
        case .beginner: keyPath = \.beginnerNoteCount
        case .normal: keyPath = \.normalNoteCount
        case .hyper: keyPath = \.hyperNoteCount
        case .another: keyPath = \.anotherNoteCount
        case .leggendaria: keyPath = \.leggendariaNoteCount
        default: keyPath = nil
        }
        if let keyPath,
           let song = songCompactTitles[compactTitle] {
            return song.spNoteCount?[keyPath: keyPath]
        } else {
            return nil
        }
    }
}
