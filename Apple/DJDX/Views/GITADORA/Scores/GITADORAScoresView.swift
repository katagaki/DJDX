import SwiftUI

struct GITADORAScoresView<Header: View>: View {

    @EnvironmentObject var navigationManager: NavigationManager

    @ViewBuilder var header: Header
    @Binding var isEditingAnalytics: Bool

    @AppStorage(wrappedValue: GITADORAVersion.galaxyWaveDelta, "Global.GITADORA.Version")
    var gitadoraVersion: GITADORAVersion
    @AppStorage(wrappedValue: GITADORAInstrument.guitar, "Global.GITADORA.Instrument")
    var instrument: GITADORAInstrument
    @AppStorage(wrappedValue: GITADORASortMode.title, "GITADORAScoresView.SortMode")
    var sortMode: GITADORASortMode
    @AppStorage(wrappedValue: SortOrder.ascending, "GITADORAScoresView.SortOrder")
    var sortOrder: SortOrder
    @AppStorage(wrappedValue: [], "GITADORAScoresView.DifficultyFilters")
    var difficultiesToShow: Set<GITADORADifficulty>
    @AppStorage(wrappedValue: [], "GITADORAScoresView.LevelFilters")
    var levelsToShow: Set<String>
    @AppStorage(wrappedValue: [], "GITADORAScoresView.ClearTypeFilters")
    var clearTypesToShow: Set<GITADORAClearType>
    @AppStorage(wrappedValue: [], "GITADORAScoresView.RankFilters")
    var ranksToShow: Set<GITADORARank>

    var isScoreDataExpandedKey: String = "GITADORAScoresView.ScoreDataExpanded"
    @State var isScoreDataExpanded: Bool
    @AppStorage(wrappedValue: true, AnalyticsSectionVisibility.scoreDataKey) var isScoreDataVisible: Bool

    @State var dataState: DataState = .initializing
    @State var records: [GITADORASongRecord] = []
    @State var searchTerm: String = ""
    @State var isShowingFilterSheet: Bool = false
    @State var isShowingShareCard: Bool = false
    @State private var chartNoteTarget: ChartNoteTarget?

    @Namespace var gitadoraNamespace

    let fetcher = GITADORAReader()

    init(isEditingAnalytics: Binding<Bool> = .constant(false), @ViewBuilder header: () -> Header) {
        self.header = header()
        self._isEditingAnalytics = isEditingAnalytics
        self.isScoreDataExpanded = (UserDefaults.standard.object(
            forKey: isScoreDataExpandedKey
        ) as? Bool) ?? true
    }

    var filteredRecords: [GITADORASongRecord] {
        var result = records.filter { $0.instrumentEnum == instrument }
        if !searchTerm.isEmpty {
            let term = searchTerm.lowercased()
            result = result.filter { $0.title.lowercased().contains(term) }
        }
        let filters = filters
        return result.filter { filters.matches($0) }
    }

    var filters: GITADORAFilterOptions {
        GITADORAFilterOptions(difficulties: difficultiesToShow,
                                  levels: levelsToShow,
                                  clearTypes: clearTypesToShow,
                                  ranks: ranksToShow)
    }

    var availableLevels: [String] {
        Array(Set(records.map { $0.levelBucket }).subtracting([""]))
            .sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
    }

    var sortedRecords: [GITADORASongRecord] {
        let base = filteredRecords
        let sorted: [GITADORASongRecord]
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
                if lhs.levelValue != rhs.levelValue { return lhs.levelValue < rhs.levelValue }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
        case .skill:
            sorted = base.sorted { lhs, rhs in
                if lhs.skillValue != rhs.skillValue { return lhs.skillValue < rhs.skillValue }
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
        let hasClear = { (record: GITADORASongRecord) in
            clearRank(record) < GITADORAClearType.sortedWithoutNoPlay.count
        }
        return ordered.filter(hasClear) + ordered.filter { !hasClear($0) }
    }

    func clearRank(_ record: GITADORASongRecord) -> Int {
        GITADORAClearType.sorted.firstIndex(of: record.clearTypeEnum)
            ?? GITADORAClearType.sorted.count
    }

    @ViewBuilder var filterControl: some View {
        Button("Shared.Filter", systemImage: "line.3.horizontal.decrease") {
            isShowingFilterSheet = true
        }
        .matchedTransitionSource(id: "GITADORAScoreFilterSheet", in: gitadoraNamespace)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0.0) {
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
                                .labelStyle(.iconOnly)
                                .font(.subheadline.weight(.bold))
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
                    ForEach(sortedRecords, id: \.self) { record in
                        Button {
                            chartNoteTarget = record.chartNoteTarget
                        } label: {
                            GITADORAScoreRow(record: record)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        Divider()
                            .padding(.leading, 16.0)
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
                game: .gitadora,
                profile: .gitadora(instrument: instrument),
                entries: sortedRecords.map { ShareCardEntry(gitadoraSongRecord: $0) },
                playStyle: instrument.displayName
            )
        }
        .sheet(item: $chartNoteTarget) { target in
            ChartNotesSheet(game: target.game, title: target.title,
                            chart: target.chart, chartLabel: target.chartLabel)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isShowingFilterSheet) {
            GITADORAScoreFilterSheet(
                sortMode: $sortMode.animation(.smooth.speed(2.0)),
                sortOrder: $sortOrder.animation(.smooth.speed(2.0)),
                difficultiesToShow: $difficultiesToShow.animation(.smooth.speed(2.0)),
                levelsToShow: $levelsToShow.animation(.smooth.speed(2.0)),
                clearTypesToShow: $clearTypesToShow.animation(.smooth.speed(2.0)),
                ranksToShow: $ranksToShow.animation(.smooth.speed(2.0)),
                availableLevels: availableLevels,
                onReset: {}
            )
            .navigationTransition(.zoom(sourceID: "GITADORAScoreFilterSheet", in: gitadoraNamespace))
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
        .onChange(of: gitadoraVersion) { _, _ in
            Task { await reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataImported)) { _ in
            Task { await reload() }
        }
    }

    func reload() async {
        dataState = .loading
        let latest = await fetcher.latestSongRecords(for: gitadoraVersion)
        await MainActor.run {
            withAnimation(.smooth.speed(2.0)) {
                records = latest
                dataState = .presenting
            }
        }
    }
}
