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
        Menu {
            Toggle("Scores.Filter.ShowWithScoreOnly",
                   systemImage: "trophy.fill",
                   isOn: $isShowingOnlyPlayDataWithScores)
            Section("Shared.Filter") {
                Picker("Shared.Difficulty", selection: $difficultyToShow) {
                    Text("Shared.All")
                        .tag(IIDXDifficulty.all)
                    ForEach(IIDXDifficulty.sorted, id: \.self) { sortDifficulty in
                        Text("LEVEL \(sortDifficulty.rawValue)")
                            .tag(sortDifficulty)
                    }
                }
                Picker("Shared.Level", selection: $levelToShow) {
                    Text("Shared.All")
                        .tag(IIDXLevel.all)
                    ForEach(IIDXLevel.sorted, id: \.self) { sortLevel in
                        Text(LocalizedStringKey(sortLevel.rawValue))
                            .tag(sortLevel)
                    }
                }
                Picker("Shared.ClearType", selection: $clearTypeToShow) {
                    Text("Shared.All")
                        .tag(IIDXClearType.all)
                    ForEach(IIDXClearType.sorted, id: \.self) { sortClearType in
                        Text(LocalizedStringKey(sortClearType.rawValue))
                            .tag(sortClearType)
                    }
                }
                Button("Shared.Filter.ResetAll", systemImage: "arrow.clockwise") {
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
        } label: {
            HStack(spacing: 8.0) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18.0, height: 18.0)
                Text("Shared.Filter")
                    .fontWeight(.medium)
            }
            .foregroundStyle(.text)
            .padding([.top, .bottom], 12.0)
            .padding([.leading, .trailing], 16.0)
            .background(.accent)
            .clipShape(.capsule)
        }
        .menuActionDismissBehavior(.disabled)
        Menu {
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
        } label: {
            HStack(spacing: 8.0) {
                Image(systemName: "arrow.up.arrow.down")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18.0, height: 18.0)
                Text("Shared.Sort")
                    .fontWeight(.medium)
            }
            .foregroundStyle(.text)
            .padding([.top, .bottom], 12.0)
            .padding([.leading, .trailing], 16.0)
            .background(.accent)
            .clipShape(.capsule)
        }
    }
}
