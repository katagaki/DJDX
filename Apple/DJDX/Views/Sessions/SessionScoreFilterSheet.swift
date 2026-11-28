import SwiftUI

struct SessionScoreFilterSheet: View {
    @Binding var sortMode: SortMode
    @Binding var sortOrder: SortOrder
    @Binding var levelsToShow: Set<IIDXLevel>
    @Binding var difficultiesToShow: Set<IIDXDifficulty>
    @Binding var clearTypesToShow: Set<IIDXClearType>
    @Binding var djLevelsToShow: Set<IIDXDJLevel>

    @AppStorage(wrappedValue: true, "ScoresView.BeginnerLevelHidden") var isBeginnerLevelHidden: Bool
    @AppStorage(wrappedValue: false, "ScoresView.GenreVisible") var isGenreVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.ArtistVisible") var isArtistVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.LevelVisible") var isLevelVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.DJLevelVisible") var isDJLevelVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.ScoreRateVisible") var isScoreRateVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.ScoreVisible") var isScoreVisible: Bool
    @AppStorage(wrappedValue: false, "ScoresView.LastPlayDateVisible") var isLastPlayDateVisible: Bool
    @AppStorage(wrappedValue: true, AnalyticsSectionVisibility.overviewKey) var isOverviewVisible: Bool
    @AppStorage(wrappedValue: true, AnalyticsSectionVisibility.lastPlayKey) var isLastPlayVisible: Bool
    @AppStorage(wrappedValue: true, AnalyticsSectionVisibility.perLevelKey) var isPerLevelVisible: Bool
    @AppStorage(wrappedValue: true, AnalyticsSectionVisibility.scoreDataKey) var isScoreDataVisible: Bool

    @Environment(\.dismiss) var dismiss

    func toggle<Value: Hashable>(_ value: Value, in set: Binding<Set<Value>>) {
        if set.wrappedValue.contains(value) {
            set.wrappedValue.remove(value)
        } else {
            set.wrappedValue.insert(value)
        }
    }

    func resetFilters() {
        levelsToShow = []
        difficultiesToShow = []
        clearTypesToShow = []
        djLevelsToShow = []
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
            ForEach(SortMode.whenLevelFiltered, id: \.self) { mode in
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
        FilterChipGroup(title: Text(.sharedLevel)) {
            ForEach(IIDXLevel.sorted.filter({ !isBeginnerLevelHidden || $0 != .beginner }), id: \.self) { level in
                let tint = IIDXLevelLabel(levelType: level, score: IIDXLevelScore()).foregroundColor()
                FilterChip(isOn: levelsToShow.contains(level),
                              isDimmed: !levelsToShow.isEmpty && !levelsToShow.contains(level),
                              fill: tint) {
                    toggle(level, in: $levelsToShow)
                } label: {
                    Text(LocalizedStringKey(level.rawValue))
                        .font(.system(size: 11.0, weight: .black))
                        .foregroundStyle(.white)
                        .strokeText(color: tint.mix(with: .black, by: 0.55), width: 0.55)
                }
            }
        }
        FilterChipGroup(title: Text(.sharedDifficulty)) {
            ForEach(IIDXDifficulty.sorted, id: \.self) { difficulty in
                FilterChip(isOn: difficultiesToShow.contains(difficulty),
                              isDimmed: !difficultiesToShow.isEmpty && !difficultiesToShow.contains(difficulty)) {
                    toggle(difficulty, in: $difficultiesToShow)
                } label: {
                    LevelNumber(level: String(difficulty.rawValue), size: 15.0)
                }
            }
        }
        FilterChipGroup(title: Text("Shared.IIDX.ClearType")) {
            ForEach(IIDXClearType.sortedWithoutNoPlay, id: \.self) { clearType in
                FilterChip(isOn: clearTypesToShow.contains(clearType),
                              isDimmed: !clearTypesToShow.isEmpty && !clearTypesToShow.contains(clearType)) {
                    toggle(clearType, in: $clearTypesToShow)
                } label: {
                    IIDXMetallicText.clearType(clearType.rawValue)
                        .font(.system(size: 12.0))
                }
            }
        }
        FilterChipGroup(title: Text("Shared.IIDX.DJLevel")) {
            ForEach(IIDXDJLevel.sorted.reversed(), id: \.self) { djLevel in
                FilterChip(isOn: djLevelsToShow.contains(djLevel),
                              isDimmed: !djLevelsToShow.isEmpty && !djLevelsToShow.contains(djLevel)) {
                    toggle(djLevel, in: $djLevelsToShow)
                } label: {
                    IIDXMetallicText.djLevel(djLevel.rawValue)
                        .font(.system(size: 14.0))
                }
            }
        }
    }

    @ViewBuilder
    var displayGroups: some View {
        FilterChipGroup(title: Text("Shared.Filter")) {
            FilterTextChip(title: Text("More.PlayDataDisplay.HideBeginnerLevel"), isOn: isBeginnerLevelHidden) {
                isBeginnerLevelHidden.toggle()
            }
        }
        FilterChipGroup(title: Text("More.PlayDataDisplay.Fields")) {
            FilterTextChip(title: Text("More.PlayDataDisplay.ShowGenre"), isOn: isGenreVisible) {
                isGenreVisible.toggle()
            }
            FilterTextChip(title: Text("More.PlayDataDisplay.ShowArtist"), isOn: isArtistVisible) {
                isArtistVisible.toggle()
            }
            FilterTextChip(title: Text("More.PlayDataDisplay.ShowLevel"), isOn: isLevelVisible) {
                isLevelVisible.toggle()
            }
            FilterTextChip(title: Text("Shared.IIDX.DJLevel"), isOn: isDJLevelVisible) {
                isDJLevelVisible.toggle()
            }
            FilterTextChip(title: Text("Shared.Sort.ScoreRate"), isOn: isScoreRateVisible) {
                isScoreRateVisible.toggle()
            }
            FilterTextChip(title: Text("Shared.Sort.Score"), isOn: isScoreVisible) {
                isScoreVisible.toggle()
            }
            FilterTextChip(title: Text("Shared.Sort.LastPlayDate"), isOn: isLastPlayDateVisible) {
                isLastPlayDateVisible.toggle()
            }
        }
        FilterChipGroup(title: Text("More.PlayDataDisplay.Sections")) {
            FilterTextChip(title: Text("Analytics.Section.Overview"), isOn: isOverviewVisible) {
                isOverviewVisible.toggle()
            }
            FilterTextChip(title: Text("Analytics.Section.LastPlay"), isOn: isLastPlayVisible) {
                isLastPlayVisible.toggle()
            }
            FilterTextChip(title: Text("Analytics.Section.PerLevel"), isOn: isPerLevelVisible) {
                isPerLevelVisible.toggle()
            }
            FilterTextChip(title: Text("Analytics.Section.ScoreData"), isOn: isScoreDataVisible) {
                isScoreDataVisible.toggle()
            }
        }
    }
}
