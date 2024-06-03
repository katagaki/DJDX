//
//  ScoresView+Functions.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/26.
//

import Foundation
import SwiftData
import SwiftUI

extension ScoresView {
    func reloadAllSongRecords() async {
        // TODO: Fix weird issues with reloading:
        // - Reload triggers filter and sort chain twice
        // - isSystemChangingAllRecords does not take effect
        // - Freeze when not using async await
        debugPrint("Removing all song records")
        isSystemChangingAllRecords = true
        await MainActor.run {
            withAnimation(.snappy.speed(2.0)) {
                displayedSongRecords.removeAll()
                displayedSongRecordsWithClearRateMapping.removeAll()
                sortedSongRecords.removeAll()
                filteredSongRecords.removeAll()
                allSongRecords.removeAll()
                allSongNoteCounts.removeAll()
            }
        }
        let newSongRecords = calendar.latestAvailableIIDXSongRecords(
            in: ModelContext(sharedModelContainer)
        )
        let newSongMappings = ((try? modelContext.fetch(FetchDescriptor<IIDXSong>(
            sortBy: [SortDescriptor(\.title, order: .forward)]
        ))) ?? [])
            .reduce(into: [:]) { partialResult, song in
                partialResult[song.title] = song.spNoteCount
            }
        debugPrint("Setting new song records")
        isSystemChangingAllRecords = false
        await MainActor.run {
            withAnimation(.snappy.speed(2.0)) {
                allSongRecords = newSongRecords
                allSongNoteCounts = newSongMappings
            }
        }
    }

    func filterSongRecords() {
        var filteredSongRecords: [IIDXSongRecord] = self.allSongRecords

        // Remove song records that have no scores
        if isShowingOnlyPlayDataWithScores {
            if let keyPath = keyPath(for: levelToShow) {
                filteredSongRecords.removeAll { songRecord in
                    songRecord[keyPath: keyPath].score == 0
                }
            } else {
                filteredSongRecords.removeAll { songRecord in
                    songRecord.beginnerScore.score == 0 &&
                    songRecord.normalScore.score == 0 &&
                    songRecord.hyperScore.score == 0 &&
                    songRecord.anotherScore.score == 0 &&
                    songRecord.leggendariaScore.score == 0
                }
            }
        }

        // Filter song records by level
        if let keyPath = keyPath(for: levelToShow) {
            filteredSongRecords.removeAll { songRecord in
                songRecord[keyPath: keyPath].difficulty == 0
            }
        }

        // Filter song records by level
        if difficultyToShow != .all {
            filteredSongRecords.removeAll { songRecord in
                songRecord.score(for: difficultyToShow) == nil
            }
        }

        self.filteredSongRecords = filteredSongRecords
    }

    // swiftlint:disable cyclomatic_complexity function_body_length
    func sortSongRecords() {
        var sortedSongRecords: [IIDXSongRecord] = self.filteredSongRecords
        var songLevelScores: [IIDXSongRecord: IIDXLevelScore] = [:]

        // Get the level score to be used for sorting
        if sortMode != .title && sortMode != .lastPlayDate {
            if levelToShow != .all, let keyPath = keyPath(for: levelToShow) {
                songLevelScores = sortedSongRecords.reduce(into: [:], { partialResult, songRecord in
                    partialResult[songRecord] = songRecord[keyPath: keyPath]
                })
            } else if difficultyToShow != .all {
                songLevelScores = sortedSongRecords.reduce(into: [:], { partialResult, songRecord in
                    partialResult[songRecord] = songRecord.score(for: difficultyToShow)
                })
            }
        }

        // Sort dictionary
        switch sortMode {
        case .title:
            sortedSongRecords.sort { lhs, rhs in
                lhs.title < rhs.title
            }
        case .clearType:
            let clearTypes = IIDXClearType.sortedStrings
            sortedSongRecords = songLevelScores
                .sorted(by: { lhs, rhs in
                    let lhsIndex = clearTypes.firstIndex(of: lhs.value.clearType)
                    let rhsIndex = clearTypes.firstIndex(of: rhs.value.clearType)
                    if lhsIndex == rhsIndex {
                        return lhs.key.title < rhs.key.title
                    } else {
                        if let lhsIndex, let rhsIndex {
                            return lhsIndex < rhsIndex
                        } else {
                            return true
                        }
                    }
                })
                .map({ $0.key })
        case .djLevel:
            let djLevels = IIDXDJLevel.sorted
            sortedSongRecords = songLevelScores
                .sorted(by: { lhs, rhs in
                    let lhsIndex = djLevels.firstIndex(of: lhs.value.djLevelEnum())
                    let rhsIndex = djLevels.firstIndex(of: rhs.value.djLevelEnum())
                    if lhsIndex == rhsIndex {
                        return lhs.key.title < rhs.key.title
                    } else {
                        if let lhsIndex, let rhsIndex {
                            return lhsIndex > rhsIndex
                        } else {
                            if lhsIndex == nil && rhsIndex != nil {
                                return false
                            } else {
                                return true
                            }
                        }
                    }
                })
                .map({ $0.key })
        case .scoreRate:
            if allSongNoteCounts.count > 0 {
                sortedSongRecords = songLevelScores
                    .sorted(by: { lhs, rhs in
                        let lhsSong = allSongNoteCounts[lhs.key.title]
                        let rhsSong = allSongNoteCounts[rhs.key.title]
                        if lhsSong == nil && rhsSong != nil {
                            return false
                        } else if lhsSong != nil && rhsSong == nil {
                            return true
                        } else if let lhsSong, let rhsSong {
                            if let lhsNoteCount = lhsSong.noteCount(for: lhs.value.level),
                               let rhsNoteCount = rhsSong.noteCount(for: rhs.value.level) {
                                let lhsScoreRate = Float(lhs.value.score) / Float(lhsNoteCount * 2)
                                let rhsScoreRate = Float(rhs.value.score) / Float(rhsNoteCount * 2)
                                if lhsScoreRate.isZero && rhsScoreRate > .zero {
                                    return false
                                } else if rhsScoreRate.isZero && rhsScoreRate > .zero {
                                    return true
                                } else if lhsScoreRate.isZero && rhsScoreRate.isZero {
                                    return lhs.key.title < rhs.key.title
                                } else {
                                    return lhsScoreRate > rhsScoreRate
                                }
                            } else {
                                return false
                            }
                        } else {
                            return lhs.key.title < rhs.key.title
                        }
                    })
                    .map({ $0.key })
            }
        case .scoreAscending:
            sortedSongRecords = songLevelScores
                .sorted(by: { lhs, rhs in
                    if lhs.value.score == rhs.value.score {
                        return lhs.key.title < rhs.key.title
                    } else {
                        return lhs.value.score < rhs.value.score
                    }
                })
                .map({ $0.key })
        case .scoreDescending:
            sortedSongRecords = songLevelScores
                .sorted(by: { lhs, rhs in
                    if lhs.value.score == rhs.value.score {
                        return lhs.key.title < rhs.key.title
                    } else {
                        return lhs.value.score > rhs.value.score
                    }
                })
                .map({ $0.key })
        case .difficultyAscending:
            sortedSongRecords = songLevelScores
                .sorted(by: { lhs, rhs in
                    if lhs.value.difficulty == rhs.value.difficulty {
                        return lhs.key.title < rhs.key.title
                    } else {
                        return lhs.value.difficulty < rhs.value.difficulty
                    }
                })
                .map({ $0.key })
        case .difficultyDescending:
            sortedSongRecords = songLevelScores
                .sorted(by: { lhs, rhs in
                    if lhs.value.difficulty == rhs.value.difficulty {
                        return lhs.key.title < rhs.key.title
                    } else {
                        return lhs.value.difficulty > rhs.value.difficulty
                    }
                })
                .map({ $0.key })
        case .lastPlayDate:
            sortedSongRecords.sort { lhs, rhs in
                lhs.lastPlayDate > rhs.lastPlayDate
            }
        }

        self.sortedSongRecords = sortedSongRecords
    }
    // swiftlint:enable cyclomatic_complexity function_body_length

    func searchSongRecords() {
        let searchTermTrimmed = searchTerm.lowercased().trimmingCharacters(in: .whitespaces)
        withAnimation(.snappy.speed(2.0)) {
            if !searchTermTrimmed.isEmpty && searchTermTrimmed.count >= 1 {
                self.displayedSongRecords = self.sortedSongRecords.filter({ songRecord in
                    songRecord.title.lowercased().contains(searchTermTrimmed) ||
                    songRecord.artist.lowercased().contains(searchTermTrimmed)
                })
            } else {
                self.displayedSongRecords = self.sortedSongRecords
                self.displayedSongRecordsWithClearRateMapping = self.sortedSongRecords
                    .reduce(into: [:], { partialResult, songRecord in
                        let song = allSongNoteCounts[songRecord.title]
                        if let song {
                            var scores: [IIDXLevelScore] = [
                                songRecord.beginnerScore,
                                songRecord.normalScore,
                                songRecord.hyperScore,
                                songRecord.anotherScore,
                                songRecord.leggendariaScore
                            ]
                            scores.removeAll(where: { $0.score == 0 })
                            let scoreRates = scores.reduce(into: [:] as [IIDXLevel: Float]) { partialResult, score in
                                if let noteCount = song.noteCount(for: score.level) {
                                    partialResult[score.level] = Float(score.score) / Float(noteCount * 2)
                                }
                            }
                            partialResult[songRecord] = scoreRates
                        }
                })
            }
            dataState = .presenting
        }
    }

    func keyPath(for level: IIDXLevel) -> KeyPath<IIDXSongRecord, IIDXLevelScore>? {
        switch levelToShow {
        case .beginner: return \.beginnerScore
        case .normal: return \.normalScore
        case .hyper: return \.hyperScore
        case .another: return \.anotherScore
        case .leggendaria: return \.leggendariaScore
        default: return nil
        }
    }
}
