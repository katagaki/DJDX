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

    @State private var isShowingFilterSheet: Bool = false

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
        Button("Shared.Filter", systemImage: "line.3.horizontal.decrease") {
            isShowingFilterSheet = true
        }
        .sheet(isPresented: $isShowingFilterSheet) {
            ScoreFilterSheet(
                isShowingOnlyPlayDataWithScores: $isShowingOnlyPlayDataWithScores,
                difficultyToShow: $difficultyToShow,
                levelToShow: $levelToShow,
                clearTypeToShow: $clearTypeToShow,
                djLevelToShow: $djLevelToShow,
                versionToShow: $versionToShow,
                isSystemChangingFilterAndSort: $isSystemChangingFilterAndSort,
                isGenreVisible: $isGenreVisible,
                isArtistVisible: $isArtistVisible,
                isLevelVisible: $isLevelVisible,
                isDJLevelVisible: $isDJLevelVisible,
                isScoreRateVisible: $isScoreRateVisible,
                isScoreVisible: $isScoreVisible,
                isLastPlayDateVisible: $isLastPlayDateVisible,
                onReset: onReset
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled()
        }
    }
}

struct ScoreFilterSheet: View {

    @Binding var isShowingOnlyPlayDataWithScores: Bool
    @Binding var difficultyToShow: IIDXDifficulty
    @Binding var levelToShow: IIDXLevel
    @Binding var clearTypeToShow: IIDXClearType
    @Binding var djLevelToShow: IIDXDJLevel
    @Binding var versionToShow: String
    @Binding var isSystemChangingFilterAndSort: Bool
    @Binding var isGenreVisible: Bool
    @Binding var isArtistVisible: Bool
    @Binding var isLevelVisible: Bool
    @Binding var isDJLevelVisible: Bool
    @Binding var isScoreRateVisible: Bool
    @Binding var isScoreVisible: Bool
    @Binding var isLastPlayDateVisible: Bool
    var onReset: () -> Void

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section(.sharedFilter) {
                    Picker(.sharedLevel, selection: $levelToShow) {
                        Text(.sharedAll)
                            .tag(IIDXLevel.all)
                        Divider()
                        ForEach(IIDXLevel.sorted, id: \.self) { sortLevel in
                            Text(LocalizedStringKey(sortLevel.rawValue))
                                .tag(sortLevel)
                        }
                    }
                    Picker(.sharedDifficulty, selection: $difficultyToShow) {
                        Text(.sharedAll)
                            .tag(IIDXDifficulty.all)
                        Divider()
                        ForEach(IIDXDifficulty.sorted, id: \.self) { sortDifficulty in
                            Text("LEVEL \(sortDifficulty.rawValue)")
                                .tag(sortDifficulty)
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
                        ForEach(IIDXDJLevel.sorted.reversed(), id: \.self) { sortDJLevel in
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
                        isSystemChangingFilterAndSort = false
                        onReset()
                    }
                }
                .pickerStyle(.menu)
                Section("More.PlayDataDisplay.Header") {
                    Toggle(
                        .scoresFilterShowWithScoreOnly, systemImage: "trophy.fill",
                        isOn: $isShowingOnlyPlayDataWithScores
                    )
                    Toggle("More.PlayDataDisplay.ShowGenre", isOn: $isGenreVisible)
                    Toggle("More.PlayDataDisplay.ShowArtist", isOn: $isArtistVisible)
                    Toggle("More.PlayDataDisplay.ShowLevel", isOn: $isLevelVisible)
                    Toggle("Shared.IIDX.DJLevel", isOn: $isDJLevelVisible)
                    Toggle("Shared.Sort.ScoreRate", isOn: $isScoreRateVisible)
                    Toggle("Shared.Sort.Score", isOn: $isScoreVisible)
                    Toggle("Shared.Sort.LastPlayDate", isOn: $isLastPlayDateVisible)
                }
            }
            .navigationTitle("Shared.Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if #available(iOS 26.0, *) {
                        Button(role: .confirm) {
                            dismiss()
                        }
                    } else {
                        Button(.sharedDone) {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
