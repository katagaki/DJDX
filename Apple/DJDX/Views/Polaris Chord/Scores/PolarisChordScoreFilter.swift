import SwiftUI

struct PolarisChordScoreFilterSheet: View {

    @Binding var sortMode: PolarisChordSortMode
    @Binding var sortOrder: SortOrder
    @Binding var difficultiesToShow: Set<PolarisChordDifficulty>
    @Binding var levelsToShow: Set<String>
    @Binding var clearTypesToShow: Set<PolarisChordClearType>
    @Binding var gradesToShow: Set<PolarisChordGrade>
    let availableLevels: [String]
    var onReset: () -> Void

    @AppStorage(wrappedValue: true, AnalyticsSectionVisibility.overviewKey) var isOverviewVisible: Bool
    @AppStorage(wrappedValue: true, AnalyticsSectionVisibility.lastPlayKey) var isLastPlayVisible: Bool
    @AppStorage(wrappedValue: true, AnalyticsSectionVisibility.scoreDataKey) var isScoreDataVisible: Bool

    @Environment(\.dismiss) var dismiss

    func resetFilters() {
        difficultiesToShow = []
        levelsToShow = []
        clearTypesToShow = []
        gradesToShow = []
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
            ForEach(PolarisChordSortMode.allCases, id: \.self) { mode in
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
            ForEach(PolarisChordDifficulty.sorted, id: \.self) { difficulty in
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
                        LevelNumber(level: level, size: 15.0)
                    }
                }
            }
        }
        FilterChipGroup(title: Text("Shared.PolarisChord.ClearType")) {
            ForEach(PolarisChordClearType.sorted, id: \.self) { clearType in
                FilterChip(isOn: clearTypesToShow.contains(clearType),
                              isDimmed: !clearTypesToShow.isEmpty && !clearTypesToShow.contains(clearType)) {
                    toggle(clearType, in: $clearTypesToShow)
                } label: {
                    Text(verbatim: clearType.abbreviation)
                        .font(.playline(size: 12.0, weight: .regular))
                        .foregroundStyle(clearType.color)
                }
            }
        }
        FilterChipGroup(title: Text("Shared.PolarisChord.Grade")) {
            ForEach(PolarisChordGrade.sorted, id: \.self) { grade in
                FilterChip(isOn: gradesToShow.contains(grade),
                              isDimmed: !gradesToShow.isEmpty && !gradesToShow.contains(grade)) {
                    toggle(grade, in: $gradesToShow)
                } label: {
                    Text(verbatim: grade.rawValue)
                        .font(.system(size: 13.0, weight: .black))
                        .fontWidth(.expanded)
                        .foregroundStyle(grade.style(colorScheme: .dark))
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
