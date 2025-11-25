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
        withAnimation(.snappy.speed(2.0)) {
            dataState = .loading
        } completion: {
            Task.detached {
                let songRecordIdentifiers = await actor.songRecords(
                    on: playDataDate,
                    filters: FilterOptions(playType: playTypeToShow,
                                           onlyPlayDataWithScores: isShowingOnlyPlayDataWithScores,
                                           level: levelToShow,
                                           difficulty: difficultyToShow,
                                           clearType: clearTypeToShow),
                    sortOptions: SortOptions(mode: sortMode)
                )
                let songCompactTitles = await actor.songCompactTitles()
                let songNoteCounts = await actor.songNoteCounts

                await MainActor.run {
                    withAnimation(.snappy.speed(2.0)) {
                        if let songRecordIdentifiers {

                            // Get song records
                            let songRecords = songRecordIdentifiers.compactMap {
                                modelContext.model(for: $0) as? IIDXSongRecord
                            }

                            // Calculate clear rates
                            let songRecordClearRates: [IIDXSongRecord: [IIDXLevel: Float]] = songRecords
                                .reduce(into: [:], { partialResult, songRecord in
                                    let song = songNoteCounts[songRecord.titleCompact()]
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
                        self.songNoteCounts = songNoteCounts

                        dataState = .presenting
                    }
                }
            }
        }
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

    func scoreRate(for songRecord: IIDXSongRecord, of level: IIDXLevel, or difficulty: IIDXDifficulty) -> Float? {
        return songRecordClearRates[songRecord]?[
            songRecord.level(for: level, or: difficulty)]
    }

    func noteCount(for songRecord: IIDXSongRecord, of level: IIDXLevel) -> Int? {
        let compactTitle = songRecord.titleCompact()
        if let keyPath = level.noteCountKeyPath,
           let songIdentifier = songCompactTitles[compactTitle],
           let song = modelContext.model(for: songIdentifier) as? IIDXSong {
            return song.spNoteCount?[keyPath: keyPath]
        } else {
            return nil
        }
    }
}
