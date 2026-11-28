import SwiftUI

protocol IIDXNewEntry: Identifiable, Hashable {
    var songRecord: IIDXSongRecord { get }
    var level: IIDXLevel { get }
    var score: IIDXLevelScore { get }
}

struct NewEntryDetailView<Entry: IIDXNewEntry>: View {
    var entries: [Entry]
    var title: String
    var showsClearTypeBreakdown: Bool = false
    var scoreDelta: ((Entry) -> Int)?

    @AppStorage var sortMode: SortMode
    @AppStorage var sortOrder: SortOrder
    @AppStorage(wrappedValue: true, "ScoresView.BeginnerLevelHidden") var isBeginnerLevelHidden: Bool

    @Namespace private var namespace

    @State private var songCompactTitles: [String: IIDXSong] = [:]
    @State private var isLoaded: Bool = false
    @State private var isLevelBreakdownExpanded: Bool = true
    @State private var isClearTypeBreakdownExpanded: Bool = true

    private let fetcher = IIDXReader()

    init(entries: [Entry],
         title: String,
         showsClearTypeBreakdown: Bool = false,
         isSessionsMode: Bool = false,
         scoreDelta: ((Entry) -> Int)? = nil) {
        self.entries = entries
        self.title = title
        self.showsClearTypeBreakdown = showsClearTypeBreakdown
        self.scoreDelta = scoreDelta
        self._sortMode = AppStorage(
            wrappedValue: .lastPlayDate,
            isSessionsMode ? "SessionsView.SortOrder" : "ScoresView.SortOrder"
        )
        self._sortOrder = AppStorage(
            wrappedValue: .descending,
            isSessionsMode ? "SessionsView.SortDirection" : "ScoresView.SortDirection"
        )
    }

    private var displayedEntries: [Entry] {
        var result = entries.filter { !isBeginnerLevelHidden || $0.level != .beginner }
        let isAscending = sortOrder == .ascending
        switch sortMode {
        case .title:
            result.sort { isAscending ? $0.songRecord.title < $1.songRecord.title
                : $0.songRecord.title > $1.songRecord.title }
        case .clearType:
            let order = IIDXClearType.ascending.filter { $0 != .noPlay }.map(\.rawValue)
            result.sort { lhs, rhs in
                let lhsIndex = order.firstIndex(of: lhs.score.clearType)
                let rhsIndex = order.firstIndex(of: rhs.score.clearType)
                if lhsIndex == rhsIndex { return lhs.songRecord.title < rhs.songRecord.title }
                guard let lhsIndex, let rhsIndex else { return lhsIndex != nil }
                return isAscending ? lhsIndex < rhsIndex : lhsIndex > rhsIndex
            }
        case .djLevel:
            let order = IIDXDJLevel.sorted
            result.sort { lhs, rhs in
                let leftIndex = order.firstIndex(of: IIDXDJLevel(rawValue: lhs.score.djLevel) ?? .none)
                let rightIndex = order.firstIndex(of: IIDXDJLevel(rawValue: rhs.score.djLevel) ?? .none)
                if leftIndex == rightIndex { return lhs.songRecord.title < rhs.songRecord.title }
                guard let leftIndex, let rightIndex else { return leftIndex != nil }
                return isAscending ? leftIndex < rightIndex : leftIndex > rightIndex
            }
        case .scoreRate:
            result.sort { lhs, rhs in
                let leftRate = scoreRate(for: lhs) ?? 0
                let rightRate = scoreRate(for: rhs) ?? 0
                if leftRate == rightRate { return lhs.songRecord.title < rhs.songRecord.title }
                return isAscending ? leftRate < rightRate : leftRate > rightRate
            }
        case .score:
            result.sort { lhs, rhs in
                if lhs.score.score == rhs.score.score { return lhs.songRecord.title < rhs.songRecord.title }
                return isAscending ? lhs.score.score < rhs.score.score : lhs.score.score > rhs.score.score
            }
        case .missCount:
            result.sort { lhs, rhs in
                if lhs.score.missCount == rhs.score.missCount { return lhs.songRecord.title < rhs.songRecord.title }
                return isAscending ? lhs.score.missCount < rhs.score.missCount
                    : lhs.score.missCount > rhs.score.missCount
            }
        case .difficulty:
            result.sort { lhs, rhs in
                if lhs.score.difficulty == rhs.score.difficulty { return lhs.songRecord.title < rhs.songRecord.title }
                return isAscending ? lhs.score.difficulty < rhs.score.difficulty
                    : lhs.score.difficulty > rhs.score.difficulty
            }
        case .lastPlayDate:
            result.sort { isAscending ? $0.songRecord.lastPlayDate < $1.songRecord.lastPlayDate
                : $0.songRecord.lastPlayDate > $1.songRecord.lastPlayDate }
        }
        return result
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0.0) {
                if entries.isEmpty {
                    Text("Analytics.NoData")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24.0)
                } else {
                    VStack(spacing: 20.0) {
                        breakdownSection(
                            title: "Analytics.Breakdown.Level",
                            isExpanded: $isLevelBreakdownExpanded,
                            items: levelItems
                        )
                        if showsClearTypeBreakdown {
                            breakdownSection(
                                title: "Analytics.Breakdown.ClearType",
                                isExpanded: $isClearTypeBreakdownExpanded,
                                items: clearTypeItems
                            )
                        }
                    }
                    .padding(.top, 12.0)
                    .padding(.bottom, 20.0)
                    if isLoaded {
                        ForEach(displayedEntries) { entry in
                            NavigationLink {
                                IIDXScoreViewer(
                                    songRecord: entry.songRecord,
                                    noteCount: noteCount,
                                    initialLevel: entry.level
                                )
                            } label: {
                                IIDXScoreRow(
                                    namespace: namespace,
                                    songRecord: entry.songRecord,
                                    level: entry.level,
                                    score: entry.score,
                                    scoreRate: scoreRate(for: entry),
                                    scoreDelta: scoreDelta?(entry)
                                )
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            songCompactTitles = await fetcher.songCompactTitles()
            isLoaded = true
        }
    }

    @ViewBuilder
    private func breakdownSection(
        title: LocalizedStringKey,
        isExpanded: Binding<Bool>,
        items: [BreakdownBarItem]
    ) -> some View {
        if !items.isEmpty {
            VStack(spacing: 12.0) {
                AnalyticsSectionHeader(
                    title: title,
                    isCollapsible: true,
                    isExpanded: isExpanded.wrappedValue
                ) {
                    withAnimation(.smooth.speed(2.0)) { isExpanded.wrappedValue.toggle() }
                }
                if isExpanded.wrappedValue {
                    BreakdownBarView(items: items)
                        .padding(.horizontal)
                }
            }
        }
    }

    private var levelItems: [BreakdownBarItem] {
        (1...12).compactMap { difficulty in
            let count = displayedEntries.filter { $0.score.difficulty == difficulty }.count
            guard count > 0 else { return nil }
            return BreakdownBarItem(
                label: "LEVEL \(difficulty)",
                count: count,
                color: Self.levelColor(difficulty),
                levelBadge: String(difficulty)
            )
        }
    }

    private var clearTypeItems: [BreakdownBarItem] {
        IIDXClearType.sortedWithoutNoPlay.compactMap { clearType in
            let count = displayedEntries.filter { $0.score.clearType == clearType.rawValue }.count
            guard count > 0 else { return nil }
            return BreakdownBarItem(
                label: IIDXClearType.abbreviation(for: clearType.rawValue),
                count: count,
                color: IIDXClearType.color(for: clearType.rawValue),
                metallicLabel: .clearType(clearType.rawValue,
                                          label: IIDXClearType.abbreviation(for: clearType.rawValue)),
                isFullCombo: clearType == .fullComboClear
            )
        }
    }

    private static func levelColor(_ difficulty: Int) -> Color {
        Color(
            hue: 0.6 - 0.6 * Double(difficulty - 1) / 11.0,
            saturation: 0.75,
            brightness: 0.9
        )
    }

    private func scoreRate(for entry: Entry) -> Float? {
        guard let noteCount = noteCount(entry.songRecord, entry.level), noteCount > 0 else { return nil }
        return Float(entry.score.score) / Float(noteCount * 2)
    }

    private func noteCount(_ songRecord: IIDXSongRecord, _ level: IIDXLevel) -> Int? {
        let keyPath: KeyPath<IIDXNoteCount, Int?>?
        switch level {
        case .beginner: keyPath = \.beginnerNoteCount
        case .normal: keyPath = \.normalNoteCount
        case .hyper: keyPath = \.hyperNoteCount
        case .another: keyPath = \.anotherNoteCount
        case .leggendaria: keyPath = \.leggendariaNoteCount
        default: keyPath = nil
        }
        guard let keyPath, let song = songCompactTitles[songRecord.titleCompact()] else { return nil }
        return song.spNoteCount?[keyPath: keyPath]
    }
}
