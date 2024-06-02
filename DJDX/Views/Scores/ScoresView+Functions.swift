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
    func reloadAllSongRecords() {
        allSongRecords = calendar.latestAvailableIIDXSongRecords(in: ModelContext(sharedModelContainer))
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
                    clearTypes.firstIndex(of: lhs.value.clearType) ?? 0 <
                        clearTypes.firstIndex(of: rhs.value.clearType) ?? 1
                })
                .map({ $0.key })
        case .djLevel:
            let djLevels = IIDXDJLevel.sorted
            sortedSongRecords = songLevelScores
                .sorted(by: { lhs, rhs in
                    djLevels.firstIndex(of: lhs.value.djLevelEnum()) ?? 1 >
                    djLevels.firstIndex(of: rhs.value.djLevelEnum()) ?? 0
                })
                .map({ $0.key })
        case .scoreAscending:
            sortedSongRecords = songLevelScores
                .sorted(by: { lhs, rhs in
                    lhs.value.score < rhs.value.score
                })
                .map({ $0.key })
        case .scoreDescending:
            sortedSongRecords = songLevelScores
                .sorted(by: { lhs, rhs in
                    lhs.value.score > rhs.value.score
                })
                .map({ $0.key })
        case .difficultyAscending:
            sortedSongRecords = songLevelScores
                .sorted(by: { lhs, rhs in
                    lhs.value.difficulty < rhs.value.difficulty
                })
                .map({ $0.key })
        case .difficultyDescending:
            sortedSongRecords = songLevelScores
                .sorted(by: { lhs, rhs in
                    lhs.value.difficulty > rhs.value.difficulty
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
