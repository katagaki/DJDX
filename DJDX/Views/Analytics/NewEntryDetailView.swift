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

    @Namespace private var namespace

    @State private var songCompactTitles: [String: IIDXSong] = [:]
    @State private var isLoaded: Bool = false
    @State private var isLevelBreakdownExpanded: Bool = true
    @State private var isClearTypeBreakdownExpanded: Bool = true

    private let fetcher = IIDXReader()

    init(entries: [Entry],
         title: String,
         showsClearTypeBreakdown: Bool = false,
         scoreDelta: ((Entry) -> Int)? = nil) {
        self.entries = entries
        self.title = title
        self.showsClearTypeBreakdown = showsClearTypeBreakdown
        self.scoreDelta = scoreDelta
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
                        ForEach(entries) { entry in
                            NavigationLink {
                                IIDXScoreViewer(
                                    songRecord: entry.songRecord,
                                    noteCount: noteCount,
                                    initialLevel: entry.level
                                )
                                .automaticNavigationTransition(
                                    id: "\(entry.songRecord.title).\(entry.level.rawValue)",
                                    in: namespace
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
            let count = entries.filter { $0.score.difficulty == difficulty }.count
            guard count > 0 else { return nil }
            return BreakdownBarItem(
                label: "LEVEL \(difficulty)",
                count: count,
                color: Self.levelColor(difficulty)
            )
        }
    }

    private var clearTypeItems: [BreakdownBarItem] {
        IIDXClearType.sortedWithoutNoPlay.compactMap { clearType in
            let count = entries.filter { $0.score.clearType == clearType.rawValue }.count
            guard count > 0 else { return nil }
            return BreakdownBarItem(
                label: IIDXClearType.abbreviation(for: clearType.rawValue),
                count: count,
                color: IIDXClearType.color(for: clearType.rawValue)
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
