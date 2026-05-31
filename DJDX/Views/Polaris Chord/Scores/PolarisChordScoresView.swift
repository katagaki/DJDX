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

    // Persisted store; `isScoreDataExpanded` mirrors it so a global `withAnimation`
    // can drive the collapse (animating @AppStorage directly does not work).
    var isScoreDataExpandedKey: String = "PolarisChordScoresView.ScoreDataExpanded"
    @State var isScoreDataExpanded: Bool

    @State var dataState: DataState = .initializing
    @State var records: [PolarisChordSongRecord] = []
    @State var searchTerm: String = ""
    @State var isShowingFilterSheet: Bool = false

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
        if !difficultiesToShow.isEmpty {
            result = result.filter { difficultiesToShow.contains($0.difficultyEnum) }
        }
        if !levelsToShow.isEmpty {
            result = result.filter { levelsToShow.contains($0.level) }
        }
        if !clearTypesToShow.isEmpty {
            result = result.filter { clearTypesToShow.contains($0.clearTypeEnum) }
        }
        if !gradesToShow.isEmpty {
            result = result.filter { gradesToShow.contains($0.gradeEnum) }
        }
        return result
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
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                return lhs.achievementRateValue > rhs.achievementRateValue
            }
        }
        return sortOrder == .ascending ? sorted : sorted.reversed()
    }

    // Lower rank is a better clear, so an ascending sort lists better clears first.
    func clearRank(_ record: PolarisChordSongRecord) -> Int {
        PolarisChordClearType.sorted.firstIndex(of: record.clearTypeEnum)
            ?? PolarisChordClearType.sorted.count
    }

    @ViewBuilder var sortControl: some View {
        Menu("Shared.Sort", systemImage: "arrow.up.arrow.down") {
            Picker("Shared.Sort", selection: $sortMode.animation(.snappy.speed(2.0))) {
                ForEach(PolarisChordSortMode.allCases, id: \.self) { mode in
                    Text(LocalizedStringKey(mode.rawValue))
                        .tag(mode)
                }
            }
            .pickerStyle(.inline)
            Section {
                Picker("Shared.Sort.Order", selection: $sortOrder.animation(.snappy.speed(2.0))) {
                    Label("Shared.Sort.Ascending", systemImage: "arrow.up")
                        .tag(SortOrder.ascending)
                    Label("Shared.Sort.Descending", systemImage: "arrow.down")
                        .tag(SortOrder.descending)
                }
                .pickerStyle(.inline)
            }
        }
        .menuOrder(.fixed)
        .menuActionDismissBehavior(.disabled)
    }

    @ViewBuilder var filterControl: some View {
        Button("Shared.Filter", systemImage: "line.3.horizontal.decrease") {
            isShowingFilterSheet = true
        }
        .automaticSheetMatchedTransitionSource(id: "PolarisChordScoreFilterSheet", in: polarisChordNamespace)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0.0) {
                if searchTerm.isEmpty {
                    header
                    if !isEditingAnalytics {
                        AnalyticsSectionHeader(
                            title: "Analytics.Section.ScoreData",
                            isCollapsible: true,
                            isExpanded: isScoreDataExpanded
                        ) {
                            withAnimation(.smooth.speed(2.0)) { isScoreDataExpanded.toggle() }
                            UserDefaults.standard.set(isScoreDataExpanded, forKey: isScoreDataExpandedKey)
                        }
                        .padding(.top, 16.0)
                        .padding(.bottom, 12.0)
                        if isScoreDataExpanded {
                            Divider()
                        }
                    }
                }
                if !isEditingAnalytics, isScoreDataExpanded || !searchTerm.isEmpty {
                    ForEach(sortedRecords, id: \.self) { record in
                        PolarisChordScoreRow(record: record)
                            .contentShape(.rect)
                        Divider()
                            .padding(.leading, 16.0)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background {
            LinearGradient(
                colors: [.backgroundGradientTop, .backgroundGradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .searchable(text: $searchTerm, prompt: "Scores.Search.Prompt")
        .refreshable {
            NotificationCenter.default.post(name: .profileRefreshRequested, object: nil)
            await reload()
        }
        .toolbar {
            if #available(iOS 26.0, *) {
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
                ToolbarSpacer(.fixed, placement: .bottomBar)
                ToolbarItemGroup(placement: .bottomBar) {
                    sortControl
                    filterControl
                }
            } else {
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    sortControl
                    filterControl
                }
            }
        }
        .sheet(isPresented: $isShowingFilterSheet) {
            PolarisChordScoreFilterSheet(
                difficultiesToShow: $difficultiesToShow.animation(.snappy.speed(2.0)),
                levelsToShow: $levelsToShow.animation(.snappy.speed(2.0)),
                clearTypesToShow: $clearTypesToShow.animation(.snappy.speed(2.0)),
                gradesToShow: $gradesToShow.animation(.snappy.speed(2.0)),
                availableLevels: availableLevels,
                onReset: {}
            )
            .automaticSheetNavigationTransition(id: "PolarisChordScoreFilterSheet", in: polarisChordNamespace)
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
