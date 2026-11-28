import SwiftUI

struct DDRScoreFilterSheet: View {

    @Binding var sortMode: DDRSortMode
    @Binding var sortOrder: SortOrder
    @Binding var isShowingOnlyPlayedCharts: Bool
    @Binding var difficultiesToShow: Set<DDRDifficulty>
    @Binding var levelsToShow: Set<Int>
    @Binding var clearLampsToShow: Set<String>
    @Binding var ranksToShow: Set<String>
    let availableLevels: [Int]
    let availableClearLamps: [String]
    let availableRanks: [String]
    var onReset: () -> Void

    @AppStorage(wrappedValue: true, AnalyticsSectionVisibility.overviewKey) var isOverviewVisible: Bool
    @AppStorage(wrappedValue: true, AnalyticsSectionVisibility.goalsKey) var isGoalsVisible: Bool
    @AppStorage(wrappedValue: true, AnalyticsSectionVisibility.scoreDataKey) var isScoreDataVisible: Bool
    @AppStorage(wrappedValue: Data(), AnalyticsSuggestionCardID.hiddenCardsKey) var hiddenSuggestionCardsData: Data

    @Environment(\.dismiss) var dismiss

    var isFlareSkillSuggestionsVisible: Bool {
        !AnalyticsSuggestionCardID.decodedHidden(from: hiddenSuggestionCardsData).contains(.ddrFlareSkill)
    }

    func toggleFlareSkillSuggestions() {
        var hidden = AnalyticsSuggestionCardID.decodedHidden(from: hiddenSuggestionCardsData)
        if hidden.contains(.ddrFlareSkill) {
            hidden.remove(.ddrFlareSkill)
        } else {
            hidden.insert(.ddrFlareSkill)
        }
        hiddenSuggestionCardsData = AnalyticsSuggestionCardID.encodedHidden(hidden)
    }

    func resetFilters() {
        difficultiesToShow = []
        levelsToShow = []
        clearLampsToShow = []
        ranksToShow = []
        onReset()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14.0) {
                    Text("Shared.Sort")
                        .sectionListHeader()
                    sortGroups
                    Text("Shared.Filter")
                        .sectionListHeader()
                        .padding(.top, 6.0)
                    filterGroups
                    Text("More.PlayDataDisplay.Header")
                        .sectionListHeader()
                        .padding(.top, 6.0)
                    displayGroups
                }
                .padding(.horizontal)
                .padding(.bottom, 24.0)
            }
            .navigationTitle("Scores.CustomizeDisplay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(.sharedFilterResetAll, systemImage: "arrow.clockwise") {
                        resetFilters()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .confirm) {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    var sortGroups: some View {
        FlowLayout(horizontalSpacing: 6.0, verticalSpacing: 6.0) {
            ForEach(DDRSortMode.allCases, id: \.self) { mode in
                FilterTextChip(title: Text(LocalizedStringKey(mode.rawValue)), isOn: sortMode == mode) {
                    sortMode = mode
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        FilterChipGroup(title: Text("Shared.Sort.Order")) {
            FilterTextChip(title: Text("Shared.Sort.Ascending"), isOn: sortOrder == .ascending) {
                sortOrder = .ascending
            }
            FilterTextChip(title: Text("Shared.Sort.Descending"), isOn: sortOrder == .descending) {
                sortOrder = .descending
            }
        }
    }

    @ViewBuilder
    var filterGroups: some View {
        FilterChipGroup(title: Text("Shared.Level")) {
            ForEach(DDRDifficulty.sorted, id: \.self) { difficulty in
                let tint = difficulty.color
                FilterChip(isOn: difficultiesToShow.contains(difficulty),
                              isDimmed: !difficultiesToShow.isEmpty && !difficultiesToShow.contains(difficulty),
                              fill: tint) {
                    toggle(difficulty, in: $difficultiesToShow)
                } label: {
                    Text(verbatim: difficulty.rawValue)
                        .font(.system(size: 11.0, weight: .black))
                        .foregroundStyle(.white)
                        .strokeText(color: tint.mix(with: .black, by: 0.55), width: 0.55)
                }
            }
        }
        if !availableLevels.isEmpty {
            FilterChipGroup(title: Text("Shared.Sort.Difficulty")) {
                ForEach(availableLevels, id: \.self) { level in
                    FilterChip(isOn: levelsToShow.contains(level),
                                  isDimmed: !levelsToShow.isEmpty && !levelsToShow.contains(level)) {
                        toggle(level, in: $levelsToShow)
                    } label: {
                        LevelNumber(level: String(level), size: 15.0)
                    }
                }
            }
        }
        if !availableClearLamps.isEmpty {
            FilterChipGroup(title: Text("Shared.DDR.ClearType")) {
                ForEach(availableClearLamps, id: \.self) { lamp in
                    FilterChip(isOn: clearLampsToShow.contains(lamp),
                                  isDimmed: !clearLampsToShow.isEmpty && !clearLampsToShow.contains(lamp)) {
                        toggle(lamp, in: $clearLampsToShow)
                    } label: {
                        Text(verbatim: lamp.uppercased())
                            .font(.playline(size: 12.0, weight: .regular))
                            .foregroundStyle(DDRSongRecord.clearColor(for: lamp))
                    }
                }
            }
        }
        if !availableRanks.isEmpty {
            FilterChipGroup(title: Text("Shared.DDR.Rank")) {
                ForEach(availableRanks, id: \.self) { rank in
                    FilterChip(isOn: ranksToShow.contains(rank),
                                  isDimmed: !ranksToShow.isEmpty && !ranksToShow.contains(rank)) {
                        toggle(rank, in: $ranksToShow)
                    } label: {
                        Text(verbatim: DDRSongRecord.rankDisplay(forStem: rank))
                            .font(.system(size: 13.0, weight: .black))
                            .fontWidth(.expanded)
                            .foregroundStyle(DDRSongRecord.rankColor(forStem: rank))
                    }
                }
            }
        }
    }

    @ViewBuilder
    var displayGroups: some View {
        FilterChipGroup(title: Text("Shared.Filter")) {
            FilterTextChip(title: Text(.scoresFilterShowWithScoreOnly), isOn: isShowingOnlyPlayedCharts) {
                isShowingOnlyPlayedCharts.toggle()
            }
        }
        FilterChipGroup(title: Text("More.PlayDataDisplay.Sections")) {
            FilterTextChip(title: Text("Analytics.Section.Overview"), isOn: isOverviewVisible) {
                isOverviewVisible.toggle()
            }
            FilterTextChip(title: Text("Goals.Title"), isOn: isGoalsVisible) {
                isGoalsVisible.toggle()
            }
            FilterTextChip(title: Text(verbatim: "FLARE SKILL"), isOn: isFlareSkillSuggestionsVisible) {
                toggleFlareSkillSuggestions()
            }
            FilterTextChip(title: Text("Analytics.Section.ScoreData"), isOn: isScoreDataVisible) {
                isScoreDataVisible.toggle()
            }
        }
    }

    func toggle<Element: Hashable>(_ element: Element, in binding: Binding<Set<Element>>) {
        if binding.wrappedValue.contains(element) {
            binding.wrappedValue.remove(element)
        } else {
            binding.wrappedValue.insert(element)
        }
    }
}
