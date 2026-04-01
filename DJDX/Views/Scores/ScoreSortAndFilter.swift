//
//  ScoreSortAndFilter.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/03.
//

import SwiftUI

struct ScoreSortAndFilter: View {

    @Binding var isShowingOnlyPlayDataWithScores: Bool
    @Binding var difficultiesToShow: Set<IIDXDifficulty>
    @Binding var levelsToShow: Set<IIDXLevel>
    @Binding var clearTypesToShow: Set<IIDXClearType>
    @Binding var djLevelsToShow: Set<IIDXDJLevel>
    @Binding var versionsToShow: Set<String>
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
                if levelsToShow.count == 1 {
                    ForEach(SortMode.whenLevelFiltered, id: \.self) { sortMode in
                        Text(LocalizedStringKey(sortMode.rawValue))
                            .tag(sortMode)
                    }
                } else if difficultiesToShow.count == 1 {
                    ForEach(SortMode.whenDifficultyFiltered, id: \.self) { sortMode in
                        Text(LocalizedStringKey(sortMode.rawValue))
                            .tag(sortMode)
                    }
                } else {
                    ForEach(SortMode.defaultModes, id: \.self) { sortMode in
                        Text(LocalizedStringKey(sortMode.rawValue))
                            .tag(sortMode)
                    }
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
                difficultiesToShow: $difficultiesToShow,
                levelsToShow: $levelsToShow,
                clearTypesToShow: $clearTypesToShow,
                djLevelsToShow: $djLevelsToShow,
                versionsToShow: $versionsToShow,
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
    @Binding var difficultiesToShow: Set<IIDXDifficulty>
    @Binding var levelsToShow: Set<IIDXLevel>
    @Binding var clearTypesToShow: Set<IIDXClearType>
    @Binding var djLevelsToShow: Set<IIDXDJLevel>
    @Binding var versionsToShow: Set<String>
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
                Section(.sharedLevel) {

                    ForEach(IIDXLevel.sorted, id: \.self) { level in
                        SelectableRow(
                            isSelected: levelsToShow.contains(level)
                        ) {
                            Text(LocalizedStringKey(level.rawValue))
                        } action: {
                            if levelsToShow.contains(level) {
                                levelsToShow.remove(level)
                            } else {
                                levelsToShow.insert(level)
                            }
                        }
                    }
                }
                Section(.sharedDifficulty) {
                    ForEach(IIDXDifficulty.sorted, id: \.self) { difficulty in
                        SelectableRow(
                            isSelected: difficultiesToShow.contains(difficulty)
                        ) {
                            Text("LEVEL \(difficulty.rawValue)")
                        } action: {
                            if difficultiesToShow.contains(difficulty) {
                                difficultiesToShow.remove(difficulty)
                            } else {
                                difficultiesToShow.insert(difficulty)
                            }
                        }
                    }
                }
                Section("Shared.IIDX.ClearType") {
                    ForEach(IIDXClearType.sorted, id: \.self) { clearType in
                        SelectableRow(
                            isSelected: clearTypesToShow.contains(clearType)
                        ) {
                            Text(LocalizedStringKey(clearType.rawValue))
                        } action: {
                            if clearTypesToShow.contains(clearType) {
                                clearTypesToShow.remove(clearType)
                            } else {
                                clearTypesToShow.insert(clearType)
                            }
                        }
                    }
                }
                Section("Shared.IIDX.DJLevel") {
                    ForEach(IIDXDJLevel.sorted.reversed(), id: \.self) { djLevel in
                        SelectableRow(
                            isSelected: djLevelsToShow.contains(djLevel)
                        ) {
                            Text(verbatim: djLevel.rawValue)
                        } action: {
                            if djLevelsToShow.contains(djLevel) {
                                djLevelsToShow.remove(djLevel)
                            } else {
                                djLevelsToShow.insert(djLevel)
                            }
                        }
                    }
                }
                Section(.sharedVersion) {
                    ForEach(IIDXVersion.allCases.reversed(), id: \.self) { version in
                        SelectableRow(
                            isSelected: versionsToShow.contains(version.marketingName)
                        ) {
                            Text(verbatim: version.marketingName)
                        } action: {
                            if versionsToShow.contains(version.marketingName) {
                                versionsToShow.remove(version.marketingName)
                            } else {
                                versionsToShow.insert(version.marketingName)
                            }
                        }
                    }
                }
                Section {
                    Button(.sharedFilterResetAll, systemImage: "arrow.clockwise") {
                        isSystemChangingFilterAndSort = true
                        difficultiesToShow = []
                        levelsToShow = []
                        clearTypesToShow = []
                        djLevelsToShow = []
                        versionsToShow = []
                        isSystemChangingFilterAndSort = false
                        onReset()
                    }
                }
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
            .listSectionSpacing(.compact)
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

private struct SelectableRow<Label: View>: View {

    var isSelected: Bool
    @ViewBuilder var label: Label
    var action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack {
                label
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .fontWeight(.semibold)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
