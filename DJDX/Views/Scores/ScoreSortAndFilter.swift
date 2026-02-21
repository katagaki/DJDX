//
//  ScoreSortAndFilter.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/03.
//

import SwiftUI

struct ScoreSortAndFilter: View {

    @Binding var isShowingOnlyPlayDataWithScores: Bool
    @Binding var difficultyToShow: IIDXDifficulty
    @Binding var levelToShow: IIDXLevel
    @Binding var clearTypeToShow: IIDXClearType
    @Binding var sortMode: SortMode
    @Binding var isSystemChangingFilterAndSort: Bool
    var onReset: () -> Void

    var body: some View {
        // Sort
        Menu("Shared.Sort", systemImage: "arrow.up.arrow.down") {
            Picker("Shared.Sort", selection: $sortMode) {
                if levelToShow != .all {
                    ForEach(SortMode.whenLevelFiltered, id: \.self) { sortMode in
                        Text(LocalizedStringKey(sortMode.rawValue))
                            .tag(sortMode)
                    }
                } else if difficultyToShow != .all {
                    ForEach(SortMode.whenDifficultyFiltered, id: \.self) { sortMode in
                        Text(LocalizedStringKey(sortMode.rawValue))
                            .tag(sortMode)
                    }
                } else {
                    Text(LocalizedStringKey(SortMode.title.rawValue))
                        .tag(SortMode.title)
                }
            }
            .pickerStyle(.inline)
        }

        // Filter
        Menu("Shared.Filter", systemImage: "line.3.horizontal.decrease.circle") {
            Toggle(
                .scoresFilterShowWithScoreOnly, systemImage: "trophy.fill",
                isOn: $isShowingOnlyPlayDataWithScores
            )
            Section(.sharedFilter) {
                Picker(.sharedDifficulty, selection: $difficultyToShow) {
                    Text(.sharedAll)
                        .tag(IIDXDifficulty.all)
                    Divider()
                    ForEach(IIDXDifficulty.sorted, id: \.self) { sortDifficulty in
                        Text("LEVEL \(sortDifficulty.rawValue)")
                            .tag(sortDifficulty)
                    }
                }
                Picker(.sharedLevel, selection: $levelToShow) {
                    Text(.sharedAll)
                        .tag(IIDXLevel.all)
                    Divider()
                    ForEach(IIDXLevel.sorted, id: \.self) { sortLevel in
                        Text(LocalizedStringKey(sortLevel.rawValue))
                            .tag(sortLevel)
                    }
                }
                Picker(.sharedClearType, selection: $clearTypeToShow) {
                    Text(.sharedAll)
                        .tag(IIDXClearType.all)
                    Divider()
                    ForEach(IIDXClearType.sorted, id: \.self) { sortClearType in
                        Text(LocalizedStringKey(sortClearType.rawValue))
                            .tag(sortClearType)
                    }
                }
                Button(.sharedFilterResetAll, systemImage: "arrow.clockwise") {
                    isSystemChangingFilterAndSort = true
                    difficultyToShow = .all
                    levelToShow = .all
                    clearTypeToShow = .all
                    sortMode = .title
                    isSystemChangingFilterAndSort = false
                    onReset()
                }
            }
            .pickerStyle(.menu)
        }
        .menuActionDismissBehavior(.disabled)
    }
}
