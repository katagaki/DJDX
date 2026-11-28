import SwiftUI

struct SDVXScoreFilterSheet: View {

    @Binding var sortMode: SDVXSortMode
    @Binding var sortOrder: SortOrder
    @Binding var difficultiesToShow: Set<SDVXDifficulty>
    @Binding var levelBucketsToShow: Set<Double>
    @Binding var clearTypesToShow: Set<SDVXClearType>
    @Binding var gradesToShow: Set<SDVXGrade>
    @Binding var scoreBelow: Int
    let availableLevelBuckets: [Double]
    var onReset: () -> Void

    @AppStorage(wrappedValue: true, AnalyticsSectionVisibility.overviewKey) var isOverviewVisible: Bool
    @AppStorage(wrappedValue: true, AnalyticsSectionVisibility.lastPlayKey) var isLastPlayVisible: Bool
    @AppStorage(wrappedValue: true, AnalyticsSectionVisibility.goalsKey) var isGoalsVisible: Bool
    @AppStorage(wrappedValue: true, AnalyticsSectionVisibility.scoreDataKey) var isScoreDataVisible: Bool
    @AppStorage(wrappedValue: Data(), AnalyticsSuggestionCardID.hiddenCardsKey) var hiddenSuggestionCardsData: Data

    @Environment(\.dismiss) var dismiss

    var isVolforceSuggestionsVisible: Bool {
        !AnalyticsSuggestionCardID.decodedHidden(from: hiddenSuggestionCardsData).contains(.sdvxVolforce)
    }

    func toggleVolforceSuggestions() {
        var hidden = AnalyticsSuggestionCardID.decodedHidden(from: hiddenSuggestionCardsData)
        if hidden.contains(.sdvxVolforce) {
            hidden.remove(.sdvxVolforce)
        } else {
            hidden.insert(.sdvxVolforce)
        }
        hiddenSuggestionCardsData = AnalyticsSuggestionCardID.encodedHidden(hidden)
    }

    func resetFilters() {
        difficultiesToShow = []
        levelBucketsToShow = []
        clearTypesToShow = []
        gradesToShow = []
        scoreBelow = 0
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
            ForEach(SDVXSortMode.allCases, id: \.self) { mode in
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
            ForEach(SDVXDifficulty.sorted, id: \.self) { difficulty in
                let tint = difficulty.color
                FilterChip(isOn: difficultiesToShow.contains(difficulty),
                              isDimmed: !difficultiesToShow.isEmpty && !difficultiesToShow.contains(difficulty),
                              fill: tint) {
                    toggle(difficulty, in: $difficultiesToShow)
                } label: {
                    Text(verbatim: difficulty.abbreviation)
                        .font(.system(size: 11.0, weight: .black))
                        .foregroundStyle(.white)
                        .strokeText(color: tint.mix(with: .black, by: 0.55), width: 0.55)
                }
            }
        }
        if !availableLevelBuckets.isEmpty {
            FilterChipGroup(title: Text("Shared.Sort.Difficulty")) {
                ForEach(availableLevelBuckets, id: \.self) { bucket in
                    FilterChip(isOn: levelBucketsToShow.contains(bucket),
                                  isDimmed: !levelBucketsToShow.isEmpty && !levelBucketsToShow.contains(bucket)) {
                        toggle(bucket, in: $levelBucketsToShow)
                    } label: {
                        LevelNumber(level: String(format: "%.1f", bucket), size: 15.0)
                    }
                }
            }
        }
        FilterChipGroup(title: Text("Shared.SDVX.ClearType")) {
            ForEach(SDVXClearType.sorted, id: \.self) { clearType in
                FilterChip(isOn: clearTypesToShow.contains(clearType),
                              isDimmed: !clearTypesToShow.isEmpty && !clearTypesToShow.contains(clearType)) {
                    toggle(clearType, in: $clearTypesToShow)
                } label: {
                    Text(verbatim: clearType.abbreviation)
                        .font(.system(size: 12.0, weight: .bold))
                        .fontWidth(.expanded)
                        .foregroundStyle(clearType.color)
                }
            }
        }
        FilterChipGroup(title: Text("Shared.SDVX.Grade")) {
            ForEach(SDVXGrade.sorted, id: \.self) { grade in
                FilterChip(isOn: gradesToShow.contains(grade),
                              isDimmed: !gradesToShow.isEmpty && !gradesToShow.contains(grade)) {
                    toggle(grade, in: $gradesToShow)
                } label: {
                    Text(verbatim: grade.rawValue)
                        .font(.system(size: 13.0, weight: .black))
                        .fontWidth(.expanded)
                        .sdvxGradeText()
                }
            }
        }
        FilterChipGroup(title: Text("Scores.Filter.SDVX.ScoreBelow")) {
            ForEach(SDVXFilterOptions.scoreThresholds, id: \.self) { threshold in
                FilterChip(isOn: scoreBelow == threshold,
                              isDimmed: scoreBelow > 0 && scoreBelow != threshold) {
                    scoreBelow = scoreBelow == threshold ? 0 : threshold
                } label: {
                    Text("Scores.Filter.SDVX.ScoreBelow.\(threshold.formatted())")
                        .font(.system(size: 12.0))
                        .sdvxScoreText()
                }
            }
        }
    }

    @ViewBuilder
    var displayGroups: some View {
        FilterChipGroup(title: Text("More.PlayDataDisplay.Sections")) {
            FilterTextChip(title: Text("Analytics.Section.Overview"), isOn: isOverviewVisible) {
                isOverviewVisible.toggle()
            }
            FilterTextChip(title: Text("Analytics.Section.LastPlay"), isOn: isLastPlayVisible) {
                isLastPlayVisible.toggle()
            }
            FilterTextChip(title: Text("Goals.Title"), isOn: isGoalsVisible) {
                isGoalsVisible.toggle()
            }
            FilterTextChip(title: Text(verbatim: "VOLFORCE"), isOn: isVolforceSuggestionsVisible) {
                toggleVolforceSuggestions()
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
