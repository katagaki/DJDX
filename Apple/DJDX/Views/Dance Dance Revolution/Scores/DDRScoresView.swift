import SwiftUI

struct DDRScoresView<Header: View>: View {

    @EnvironmentObject var navigationManager: NavigationManager

    @ViewBuilder var header: Header
    @Binding var isEditingAnalytics: Bool

    @AppStorage(wrappedValue: DDRVersion.world, "Global.DDR.Version") var ddrVersion: DDRVersion
    @AppStorage(wrappedValue: DDRPlayStyle.single, "Global.DDR.Style") var ddrStyleToShow: DDRPlayStyle
    @AppStorage(wrappedValue: true, "DDRScoresView.ScoreAvailableOnlyFilter") var isShowingOnlyPlayedCharts: Bool
    @AppStorage(wrappedValue: DDRSortMode.title, "DDRScoresView.SortMode") var sortMode: DDRSortMode
    @AppStorage(wrappedValue: SortOrder.ascending, "DDRScoresView.SortOrder") var sortOrder: SortOrder
    @AppStorage(wrappedValue: [], "DDRScoresView.DifficultyFilters") var difficultiesToShow: Set<DDRDifficulty>
    @AppStorage(wrappedValue: [], "DDRScoresView.LevelFilters") var levelsToShow: Set<Int>
    @AppStorage(wrappedValue: [], "DDRScoresView.ClearLampFilters") var clearLampsToShow: Set<String>
    @AppStorage(wrappedValue: [], "DDRScoresView.RankFilters") var ranksToShow: Set<String>

    var isScoreDataExpandedKey: String = "DDRScoresView.ScoreDataExpanded"
    @State var isScoreDataExpanded: Bool
    @AppStorage(wrappedValue: true, AnalyticsSectionVisibility.scoreDataKey) var isScoreDataVisible: Bool

    @State var dataState: DataState = .initializing
    @State var records: [DDRSongRecord] = []
    @State var searchTerm: String = ""
    @State var isShowingFilterSheet: Bool = false
    @State var isShowingShareCard: Bool = false

    @Namespace var ddrNamespace

    let fetcher = DDRReader()

    init(isEditingAnalytics: Binding<Bool> = .constant(false), @ViewBuilder header: () -> Header) {
        self.header = header()
        self._isEditingAnalytics = isEditingAnalytics
        self.isScoreDataExpanded = (UserDefaults.standard.object(
            forKey: isScoreDataExpandedKey
        ) as? Bool) ?? true
    }

    var styleRecords: [DDRSongRecord] {
        records.filter { $0.styleEnum == ddrStyleToShow }
    }

    var availableLevels: [Int] {
        Set(styleRecords.map { $0.level }.filter { $0 > 0 }).sorted()
    }

    var availableClearLamps: [String] {
        DDRSongRecord.orderedClearLamps(Set(styleRecords.compactMap { $0.clearKind.isEmpty ? nil : $0.clearKind }))
    }

    var availableRanks: [String] {
        DDRSongRecord.orderedRanks(Set(styleRecords.compactMap { $0.rank.isEmpty ? nil : $0.rank }))
    }

    var filteredRecords: [DDRSongRecord] {
        var result = styleRecords
        if !searchTerm.isEmpty {
            let term = searchTerm.lowercased()
            result = result.filter { $0.title.lowercased().contains(term) }
        }
        let filters = filters
        return result.filter { filters.matches($0) }
    }

    var filters: DDRFilterOptions {
        DDRFilterOptions(onlyPlayedCharts: isShowingOnlyPlayedCharts,
                         difficulties: difficultiesToShow,
                         levels: levelsToShow,
                         clearLamps: clearLampsToShow,
                         ranks: ranksToShow)
    }

    var sortedRecords: [DDRSongRecord] {
        let base = filteredRecords
        let sorted: [DDRSongRecord]
        switch sortMode {
        case .title:
            sorted = base.sorted { titleThenDifficulty($0, $1) }
        case .score:
            sorted = base.sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score < rhs.score }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
        case .clearLamp:
            sorted = base.sorted { lhs, rhs in
                if lhs.clearLampSortIndex != rhs.clearLampSortIndex {
                    return lhs.clearLampSortIndex > rhs.clearLampSortIndex
                }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
        case .level:
            sorted = base.sorted { lhs, rhs in
                if lhs.level != rhs.level { return lhs.level < rhs.level }
                return titleThenDifficulty(lhs, rhs)
            }
        }
        let ordered = sortOrder == .ascending ? sorted : sorted.reversed()
        guard sortMode == .clearLamp else { return ordered }
        let hasClearLamp = { (record: DDRSongRecord) in
            record.clearLampSortIndex < DDRSongRecord.clearLampOrder.count
        }
        return ordered.filter(hasClearLamp) + ordered.filter { !hasClearLamp($0) }
    }

    func siblingCharts(of record: DDRSongRecord) -> [DDRSongRecord] {
        styleRecords
            .filter { $0.titleCompact() == record.titleCompact() }
            .sorted { lhs, rhs in
                let lhsRank = DDRDifficulty.sorted.firstIndex(of: lhs.difficultyEnum) ?? Int.max
                let rhsRank = DDRDifficulty.sorted.firstIndex(of: rhs.difficultyEnum) ?? Int.max
                return lhsRank < rhsRank
            }
    }

    func titleThenDifficulty(_ lhs: DDRSongRecord, _ rhs: DDRSongRecord) -> Bool {
        if lhs.titleCompact() != rhs.titleCompact() {
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
        let lhsRank = DDRDifficulty.sorted.firstIndex(of: lhs.difficultyEnum) ?? Int.max
        let rhsRank = DDRDifficulty.sorted.firstIndex(of: rhs.difficultyEnum) ?? Int.max
        return lhsRank < rhsRank
    }

    @ViewBuilder var filterControl: some View {
        Button("Shared.Filter", systemImage: "line.3.horizontal.decrease") {
            isShowingFilterSheet = true
        }
        .matchedTransitionSource(id: "DDRScoreFilterSheet", in: ddrNamespace)
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
                            navigationManager.push(DDRScoresPath.scoreViewer(songRecord: record))
                        } label: {
                            DDRScoreRow(record: record)
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
                game: .danceDanceRevolution,
                profile: .ddr(style: ddrStyleToShow),
                entries: sortedRecords.map { ShareCardEntry(ddrSongRecord: $0) },
                playStyle: ddrStyleToShow == .single ? "SP" : "DP"
            )
        }
        .sheet(isPresented: $isShowingFilterSheet) {
            DDRScoreFilterSheet(
                sortMode: $sortMode.animation(.smooth.speed(2.0)),
                sortOrder: $sortOrder.animation(.smooth.speed(2.0)),
                isShowingOnlyPlayedCharts: $isShowingOnlyPlayedCharts.animation(.smooth.speed(2.0)),
                difficultiesToShow: $difficultiesToShow.animation(.smooth.speed(2.0)),
                levelsToShow: $levelsToShow.animation(.smooth.speed(2.0)),
                clearLampsToShow: $clearLampsToShow.animation(.smooth.speed(2.0)),
                ranksToShow: $ranksToShow.animation(.smooth.speed(2.0)),
                availableLevels: availableLevels,
                availableClearLamps: availableClearLamps,
                availableRanks: availableRanks,
                onReset: {}
            )
            .navigationTransition(.zoom(sourceID: "DDRScoreFilterSheet", in: ddrNamespace))
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled()
        }
        .background {
            if dataState == .presenting && filteredRecords.isEmpty {
                ContentUnavailableView("Shared.NoData", systemImage: "questionmark.square.dashed")
            }
        }
        .navigationDestination(for: DDRScoresPath.self) { viewPath in
            switch viewPath {
            case .scoreViewer(let songRecord):
                DDRScoreViewer(songRecords: siblingCharts(of: songRecord),
                               initialDifficulty: songRecord.difficultyEnum)
            }
        }
        .task {
            if dataState == .initializing {
                await reload()
            }
        }
        .onChange(of: ddrVersion) { _, _ in
            Task { await reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataImported)) { _ in
            Task { await reload() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .externalDataChanged)) { _ in
            Task { await reload() }
        }
    }

    func reload() async {
        dataState = .loading
        let latest = await fetcher.latestSongRecords(for: ddrVersion)
        await MainActor.run {
            withAnimation(.smooth.speed(2.0)) {
                records = latest
                dataState = .presenting
            }
        }
    }
}
