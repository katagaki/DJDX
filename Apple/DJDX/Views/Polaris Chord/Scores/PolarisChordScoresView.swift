import SwiftUI

struct PolarisChordScoresView<Header: View>: View {

    @EnvironmentObject var navigationManager: NavigationManager

    @ViewBuilder var header: Header
    @Binding var isEditingAnalytics: Bool

    @AppStorage(wrappedValue: PolarisChordVersion.polarisChord, "Global.PolarisChord.Version")
    var polarisChordVersion: PolarisChordVersion
    @AppStorage(wrappedValue: PolarisChordSortMode.title, "PolarisChordScoresView.SortMode")
    var sortMode: PolarisChordSortMode
    @AppStorage(wrappedValue: SortOrder.ascending, "PolarisChordScoresView.SortOrder")
    var sortOrder: SortOrder
    @AppStorage(wrappedValue: [], "PolarisChordScoresView.DifficultyFilters")
    var difficultiesToShow: Set<PolarisChordDifficulty>
    @AppStorage(wrappedValue: [], "PolarisChordScoresView.LevelFilters")
    var levelsToShow: Set<String>
    @AppStorage(wrappedValue: [], "PolarisChordScoresView.ClearTypeFilters")
    var clearTypesToShow: Set<PolarisChordClearType>
    @AppStorage(wrappedValue: [], "PolarisChordScoresView.GradeFilters")
    var gradesToShow: Set<PolarisChordGrade>

    var isScoreDataExpandedKey: String = "PolarisChordScoresView.ScoreDataExpanded"
    @State var isScoreDataExpanded: Bool
    @AppStorage(wrappedValue: true, AnalyticsSectionVisibility.scoreDataKey) var isScoreDataVisible: Bool

    @State var dataState: DataState = .initializing
    @State var records: [PolarisChordSongRecord] = []
    @State var searchTerm: String = ""
    @State var isShowingFilterSheet: Bool = false
    @State var isShowingShareCard: Bool = false
    @State private var chartNoteTarget: ChartNoteTarget?

    @Namespace var polarisChordNamespace

    let fetcher = PolarisChordReader()

    init(isEditingAnalytics: Binding<Bool> = .constant(false), @ViewBuilder header: () -> Header) {
        self.header = header()
        self._isEditingAnalytics = isEditingAnalytics
        self.isScoreDataExpanded = (UserDefaults.standard.object(
            forKey: isScoreDataExpandedKey
        ) as? Bool) ?? true
    }

    var filteredRecords: [PolarisChordSongRecord] {
        var result = records
        if !searchTerm.isEmpty {
            let term = searchTerm.lowercased()
            result = result.filter { $0.title.lowercased().contains(term) }
        }
        let filters = filters
        return result.filter { filters.matches($0) }
    }

    var filters: PolarisChordFilterOptions {
        PolarisChordFilterOptions(difficulties: difficultiesToShow,
                                  levels: levelsToShow,
                                  clearTypes: clearTypesToShow,
                                  grades: gradesToShow)
    }

    // Levels are strings like "12" or "12+"; order by numeric base, "+" after.
    func levelOrder(_ level: String) -> Double {
        let base = Double(level.replacingOccurrences(of: "+", with: "")) ?? 0.0
        return level.contains("+") ? base + 0.5 : base
    }

    var availableLevels: [String] {
        Array(Set(records.map { $0.level }).subtracting([""]))
            .sorted { levelOrder($0) < levelOrder($1) }
    }

    var sortedRecords: [PolarisChordSongRecord] {
        let base = filteredRecords
        let sorted: [PolarisChordSongRecord]
        switch sortMode {
        case .title:
            sorted = base.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .rate:
            sorted = base.sorted { lhs, rhs in
                if lhs.achievementRateValue != rhs.achievementRateValue {
                    return lhs.achievementRateValue < rhs.achievementRateValue
                }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
        case .level:
            sorted = base.sorted { lhs, rhs in
                let lhsLevel = levelOrder(lhs.level)
                let rhsLevel = levelOrder(rhs.level)
                if lhsLevel != rhsLevel { return lhsLevel < rhsLevel }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
        case .clearType:
            sorted = base.sorted { lhs, rhs in
                let lhsRank = clearRank(lhs)
                let rhsRank = clearRank(rhs)
                if lhsRank != rhsRank { return lhsRank > rhsRank }
                return lhs.achievementRateValue > rhs.achievementRateValue
            }
        }
        let ordered = sortOrder == .ascending ? sorted : sorted.reversed()
        guard sortMode == .clearType else { return ordered }
        let hasClear = { (record: PolarisChordSongRecord) in
            clearRank(record) < PolarisChordClearType.sortedWithoutNoPlay.count
        }
        return ordered.filter(hasClear) + ordered.filter { !hasClear($0) }
    }

    func clearRank(_ record: PolarisChordSongRecord) -> Int {
        PolarisChordClearType.sorted.firstIndex(of: record.clearTypeEnum)
            ?? PolarisChordClearType.sorted.count
    }

    @ViewBuilder var filterControl: some View {
        Button("Shared.Filter", systemImage: "line.3.horizontal.decrease") {
            isShowingFilterSheet = true
        }
        .matchedTransitionSource(id: "PolarisChordScoreFilterSheet", in: polarisChordNamespace)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0.0) {
                if searchTerm.isEmpty {
                    header
                    if !isEditingAnalytics, isScoreDataVisible {
                        AnalyticsSectionHeader(
                            title: "Analytics.Section.ScoreData",
                            isCollapsible: true,
                            isExpanded: isScoreDataExpanded
                        ) {
                            withAnimation(.smooth.speed(2.0)) { isScoreDataExpanded.toggle() }
                            UserDefaults.standard.set(isScoreDataExpanded, forKey: isScoreDataExpandedKey)
                        } accessory: {
                            if !sortedRecords.isEmpty {
                                Button("ShareCard.Title", systemImage: "square.and.arrow.up") {
                                    isShowingShareCard = true
                                }
                                .sectionHeaderButton()
                            }
                        }
                        .padding(.top, DesignMetrics.sectionGap)
                        .padding(.bottom, isScoreDataExpanded ? 8.0 : 0.0)
                        if isScoreDataExpanded {
                            Divider()
                        }
                    }
                }
                if !isEditingAnalytics, (isScoreDataVisible && isScoreDataExpanded) || !searchTerm.isEmpty {
                    let sortedRecords = sortedRecords
                    LazyVStack(spacing: 0.0) {
                        ForEach(sortedRecords, id: \.self) { record in
                            Button {
                                chartNoteTarget = record.chartNoteTarget
                            } label: {
                                PolarisChordScoreRow(record: record)
                                    .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            Divider()
                                .padding(.leading, 16.0)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background {
            AppBackgroundGradient()
        }
        .searchable(text: $searchTerm, prompt: "Scores.Search.Prompt")
        .refreshable {
            NotificationCenter.default.post(name: .profileRefreshRequested, object: nil)
            await reload()
        }
        .toolbar {
            DefaultToolbarItem(kind: .search, placement: .bottomBar)
            ToolbarSpacer(.fixed, placement: .bottomBar)
            ToolbarItemGroup(placement: .bottomBar) {
                filterControl
            }
        }
        .sheet(isPresented: $isShowingShareCard) {
            ShareCardComposer(
                game: .polarisChord,
                profile: .polarisChord(),
                entries: sortedRecords.map { ShareCardEntry(polarisChordSongRecord: $0) }
            )
        }
        .sheet(item: $chartNoteTarget) { target in
            ChartNotesSheet(game: target.game, title: target.title,
                            chart: target.chart, chartLabel: target.chartLabel)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isShowingFilterSheet) {
            PolarisChordScoreFilterSheet(
                sortMode: $sortMode.animation(.smooth.speed(2.0)),
                sortOrder: $sortOrder.animation(.smooth.speed(2.0)),
                difficultiesToShow: $difficultiesToShow.animation(.smooth.speed(2.0)),
                levelsToShow: $levelsToShow.animation(.smooth.speed(2.0)),
                clearTypesToShow: $clearTypesToShow.animation(.smooth.speed(2.0)),
                gradesToShow: $gradesToShow.animation(.smooth.speed(2.0)),
                availableLevels: availableLevels,
                onReset: {}
            )
            .navigationTransition(.zoom(sourceID: "PolarisChordScoreFilterSheet", in: polarisChordNamespace))
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled()
        }
        .background {
            if dataState == .presenting && records.isEmpty {
                ContentUnavailableView("Shared.NoData", systemImage: "questionmark.square.dashed")
            }
        }
        .task {
            if dataState == .initializing {
                await reload()
            }
        }
        .onChange(of: polarisChordVersion) { _, _ in
            Task { await reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataImported)) { _ in
            Task { await reload() }
        }
    }

    func reload() async {
        dataState = .loading
        let latest = await fetcher.latestSongRecords(for: polarisChordVersion)
        await MainActor.run {
            withAnimation(.smooth.speed(2.0)) {
                records = latest
                dataState = .presenting
            }
        }
    }
}
