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
                Section(.sharedFilter) {
                    multiSelectMenu(
                        .sharedLevel,
                        items: IIDXLevel.sorted,
                        selection: $levelsToShow,
                        label: { Text(LocalizedStringKey($0.rawValue)) }
                    )
                    multiSelectMenu(
                        .sharedDifficulty,
                        items: IIDXDifficulty.sorted,
                        selection: $difficultiesToShow,
                        label: { Text("LEVEL \($0.rawValue)") }
                    )
                    multiSelectMenu(
                        "Shared.IIDX.ClearType",
                        items: IIDXClearType.sorted,
                        selection: $clearTypesToShow,
                        label: { Text(LocalizedStringKey($0.rawValue)) }
                    )
                    multiSelectMenu(
                        "Shared.IIDX.DJLevel",
                        items: IIDXDJLevel.sorted.reversed(),
                        selection: $djLevelsToShow,
                        label: { Text(verbatim: $0.rawValue) }
                    )
                    multiSelectMenu(
                        .sharedVersion,
                        items: IIDXVersion.allCases.reversed(),
                        selection: $versionsToShow,
                        id: \.marketingName,
                        label: { Text(verbatim: $0.marketingName) }
                    )
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

    // MARK: Multi-Select Menu (Hashable items)

    private func multiSelectMenu<Item: Hashable>(
        _ title: LocalizedStringKey,
        items: [Item],
        selection: Binding<Set<Item>>,
        label: @escaping (Item) -> Text
    ) -> some View {
        Menu {
            ForEach(items, id: \.self) { item in
                Button {
                    if selection.wrappedValue.contains(item) {
                        selection.wrappedValue.remove(item)
                    } else {
                        selection.wrappedValue.insert(item)
                    }
                } label: {
                    if selection.wrappedValue.contains(item) {
                        Label { label(item) } icon: {
                            Image(systemName: "checkmark")
                        }
                    } else {
                        label(item)
                    }
                }
            }
        } label: {
            LabeledContent {
                if selection.wrappedValue.isEmpty {
                    Text(.sharedAll)
                        .foregroundStyle(.secondary)
                } else {
                    Text(verbatim: "\(selection.wrappedValue.count)")
                        .foregroundStyle(.secondary)
                }
            } label: {
                Text(title)
            }
        }
        .menuActionDismissBehavior(.disabled)
    }

    // MARK: Multi-Select Menu (custom ID key path for non-Hashable display)

    private func multiSelectMenu<Item: Hashable, ID: Hashable>(
        _ title: LocalizedStringKey,
        items: [Item],
        selection: Binding<Set<ID>>,
        id keyPath: KeyPath<Item, ID>,
        label: @escaping (Item) -> Text
    ) -> some View {
        Menu {
            ForEach(items, id: keyPath) { item in
                let itemID = item[keyPath: keyPath]
                Button {
                    if selection.wrappedValue.contains(itemID) {
                        selection.wrappedValue.remove(itemID)
                    } else {
                        selection.wrappedValue.insert(itemID)
                    }
                } label: {
                    if selection.wrappedValue.contains(itemID) {
                        Label { label(item) } icon: {
                            Image(systemName: "checkmark")
                        }
                    } else {
                        label(item)
                    }
                }
            }
        } label: {
            LabeledContent {
                if selection.wrappedValue.isEmpty {
                    Text(.sharedAll)
                        .foregroundStyle(.secondary)
                } else {
                    Text(verbatim: "\(selection.wrappedValue.count)")
                        .foregroundStyle(.secondary)
                }
            } label: {
                Text(title)
            }
        }
        .menuActionDismissBehavior(.disabled)
    }
}
