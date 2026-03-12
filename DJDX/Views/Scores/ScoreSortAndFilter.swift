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
    @Binding var djLevelToShow: IIDXDJLevel
    @Binding var versionToShow: String
    @Binding var sortMode: SortMode
    @Binding var sortOrder: SortOrder
    @Binding var isSystemChangingFilterAndSort: Bool
    var onReset: () -> Void

    @AppStorage(wrappedValue: false, "ScoresView.GenreVisible") var isGenreVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.ArtistVisible") var isArtistVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.LevelVisible") var isLevelVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.DJLevelVisible") var isDJLevelVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.ScoreRateVisible") var isScoreRateVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.ScoreVisible") var isScoreVisible: Bool
    @AppStorage(wrappedValue: false, "ScoresView.LastPlayDateVisible") var isLastPlayDateVisible: Bool

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
            Section {
                Picker("Shared.Sort.Order", selection: $sortOrder) {
                    Label("Shared.Sort.Ascending", systemImage: "arrow.up")
                        .tag(SortOrder.ascending)
                    Label("Shared.Sort.Descending", systemImage: "arrow.down")
                        .tag(SortOrder.descending)
                }
                .pickerStyle(.inline)
            }
        }
        .menuActionDismissBehavior(.disabled)

        // Filter
        Menu("Shared.Filter", systemImage: "line.3.horizontal.decrease") {
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
                Picker("Shared.IIDX.ClearType", selection: $clearTypeToShow) {
                    Text(.sharedAll)
                        .tag(IIDXClearType.all)
                    Divider()
                    ForEach(IIDXClearType.sorted, id: \.self) { sortClearType in
                        Text(LocalizedStringKey(sortClearType.rawValue))
                            .tag(sortClearType)
                    }
                }
                Picker("Shared.IIDX.DJLevel", selection: $djLevelToShow) {
                    Text(.sharedAll)
                        .tag(IIDXDJLevel.all)
                    Divider()
                    ForEach(IIDXDJLevel.sorted, id: \.self) { sortDJLevel in
                        Text(verbatim: sortDJLevel.rawValue)
                            .tag(sortDJLevel)
                    }
                }
                Picker(.sharedVersion, selection: $versionToShow) {
                    Text(.sharedAll)
                        .tag("")
                    Divider()
                    ForEach(IIDXVersion.allCases.reversed(), id: \.self) { version in
                        Text(verbatim: version.marketingName)
                            .tag(version.marketingName)
                    }
                }
                Button(.sharedFilterResetAll, systemImage: "arrow.clockwise") {
                    isSystemChangingFilterAndSort = true
                    difficultyToShow = .all
                    levelToShow = .all
                    clearTypeToShow = .all
                    djLevelToShow = .all
                    versionToShow = ""
                    sortMode = .title
                    sortOrder = .ascending
                    isSystemChangingFilterAndSort = false
                    onReset()
                }
            }
            .pickerStyle(.menu)
            Section("More.PlayDataDisplay.Header") {
                Toggle("More.PlayDataDisplay.ShowGenre", isOn: $isGenreVisible)
                Toggle("More.PlayDataDisplay.ShowArtist", isOn: $isArtistVisible)
                Toggle("More.PlayDataDisplay.ShowLevel", isOn: $isLevelVisible)
                Toggle("Shared.IIDX.DJLevel", isOn: $isDJLevelVisible)
                Toggle("Shared.Sort.ScoreRate", isOn: $isScoreRateVisible)
                Toggle("Shared.Sort.Score", isOn: $isScoreVisible)
                Toggle("Shared.Sort.LastPlayDate", isOn: $isLastPlayDateVisible)
            }
        }
        .menuActionDismissBehavior(.disabled)
    }
}
