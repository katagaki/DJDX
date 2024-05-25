//
//  ScoresView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/18.
//

import SwiftUI
import SwiftData

struct ScoresView: View {

    @Environment(\.modelContext) var modelContext

    @EnvironmentObject var navigationManager: NavigationManager
    @EnvironmentObject var calendar: CalendarManager

    @State var songRecords: [IIDXSongRecord] = []

    @State var searchTerm: String = ""
    @AppStorage(wrappedValue: true, "ScoresView.LevelVisible") var isLevelVisible: Bool
    @AppStorage(wrappedValue: true, "ScorewView.GenreVisible") var isGenreVisible: Bool
    @AppStorage(wrappedValue: .all, "ScoresView.LevelFilter") var levelToShow: IIDXLevel
    @AppStorage(wrappedValue: false, "ScoresView.ScoreAvailableOnlyFilter") var isShowingOnlyPlayDataWithScores: Bool
    @AppStorage(wrappedValue: .title, "ScoresView.SortOrder") var sortMode: SortMode

    var displayParameters: [String] {[
        searchTerm, levelToShow.rawValue, String(isShowingOnlyPlayDataWithScores), sortMode.rawValue
    ]}

    @State var dataState: DataState = .initializing

    let clearTypes: [String] = [
        "FULLCOMBO CLEAR",
        "CLEAR",
        "ASSIST CLEAR",
        "EASY CLEAR",
        "HARD CLEAR",
        "EX HARD CLEAR",
        "FAILED",
        "NO PLAY"
    ]

    var body: some View {
        NavigationStack(path: $navigationManager[.scores]) {
            List {
                ForEach(songRecords, id: \.title) { songRecord in
                    NavigationLink(value: ViewPath.scoreViewer(songRecord: songRecord)) {
                        VStack(alignment: .trailing, spacing: 4.0) {
                            HStack(alignment: .center, spacing: 8.0) {
                                VStack(alignment: .leading, spacing: 2.0) {
                                    DetailedSongTitle(songRecord: songRecord,
                                                      isGenreVisible: $isGenreVisible)
                                }
                                Spacer(minLength: 0.0)
                                if isLevelVisible, levelToShow != .all {
                                    IIDXLevelLabel(levelType: levelToShow, songRecord: songRecord)
                                }
                            }
                            if isLevelVisible, levelToShow == .all {
                                IIDXLevelShowcase(songRecord: songRecord)
                            }
                        }
                    }
                    .padding([.top, .bottom], 8.0)
                    .listRowInsets(.init(top: 0.0, leading: 0.0, bottom: 0.0, trailing: 20.0))
                    .safeAreaInset(edge: .leading) {
                        VStack {
                            if let score = score(for: songRecord) {
                                switch score.clearType {
                                case "FULLCOMBO CLEAR":
                                    LinearGradient(gradient: Gradient(colors: [Color.red,
                                                                               Color.orange,
                                                                               Color.yellow,
                                                                               Color.green,
                                                                               Color.blue,
                                                                               Color.indigo,
                                                                               Color.purple]),
                                                   startPoint: .top,
                                                   endPoint: .bottom)
                                case "CLEAR": Color.cyan
                                case "ASSIST CLEAR": Color.purple
                                case "EASY CLEAR": Color.green
                                case "HARD CLEAR": Color.pink
                                case "EX HARD CLEAR": Color.yellow
                                case "FAILED": Color.red
                                default: Color.clear
                                }
                            } else {
                                Color.clear
                            }
                        }
                        .frame(width: 12.0)
                        .shadow(color: .black.opacity(0.2), radius: 1.0, x: 2.0)
                    }
                }
            }
            .navigationTitle("プレーデータ")
            .listStyle(.plain)
            .searchable(text: $searchTerm,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "曲名、アーティスト名")
            .refreshable {
                reloadScores()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Section("レベル") {
                            Picker(selection: $levelToShow) {
                                ForEach(IIDXLevel.sortLevels, id: \.self) { sortLevel in
                                    Text(sortLevel.rawValue)
                                        .tag(sortLevel)
                                }
                            } label: {
                                Text("レベル")
                            }
                        }
                        if levelToShow != .all {
                            Section("並べ替え") {
                                Picker(selection: $sortMode) {
                                    ForEach(SortMode.all, id: \.self) { sortMode in
                                        Text(sortMode.rawValue)
                                            .tag(sortMode)
                                    }
                                } label: {
                                    Text("並べ替え")
                                }
                            }
                        }
                        Section {
                            Toggle("スコアのある曲のみ表示", isOn: $isShowingOnlyPlayDataWithScores)
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .overlay {
                switch dataState {
                case .initializing, .loading:
                    ProgressView()
                        .progressViewStyle(.circular)
                case .presenting:
                    if songRecords.count == 0 {
                        ContentUnavailableView("該当するデータはありません。", systemImage: "questionmark.square.dashed")
                    } else {
                        Color.clear
                    }
                }
            }
            .task {
                if dataState == .initializing {
                    reloadScores()
                }
            }
            .onChange(of: displayParameters) { _, _ in
                reloadScores()
            }
            .onChange(of: calendar.selectedDate) { oldValue, newValue in
                if !Calendar.current.isDate(oldValue, inSameDayAs: newValue) {
                    dataState = .initializing
                }
            }
            .navigationDestination(for: ViewPath.self) { viewPath in
                switch viewPath {
                case .scoreViewer(let songRecord): ScoreViewer(songRecord: songRecord)
                default: Color.clear
                }
            }
        }
    }

    func reloadScores() {
        withAnimation(.snappy.speed(2.0)) {
            songRecords.removeAll()
            dataState = .loading
            Task.detached(priority: .high) {
                let newSongRecords: [IIDXSongRecord] = await ScoresView
                    .latestAvailableIIDXSongRecords(in: ModelContext(sharedModelContainer),
                                                    using: calendar)
                let filteredSongRecords = await filterSongRecords(newSongRecords)
                await MainActor.run { [filteredSongRecords] in
                    withAnimation(.snappy.speed(2.0)) {
                        songRecords.append(contentsOf: filteredSongRecords)
                        dataState = .presenting
                    }
                }
            }
        }
    }

    // swiftlint:disable cyclomatic_complexity
    func filterSongRecords(_ songRecords: [IIDXSongRecord]) -> [IIDXSongRecord] {
        // Filter by search term
        var filteredSongRecords: [IIDXSongRecord] = songRecords
        if searchTerm.trimmingCharacters(in: .whitespaces) != "" {
            let searchTermTrimmed = searchTerm.lowercased().trimmingCharacters(in: .whitespaces)
            filteredSongRecords = filteredSongRecords.filter({ songRecord in
                return songRecord.title.lowercased().contains(searchTermTrimmed) ||
                songRecord.artist.lowercased().contains(searchTermTrimmed)
            })
        }

        // Filter song records
        switch levelToShow {
        case .beginner:
            filteredSongRecords = filteredSongRecords.filter({ songRecord in
                return songRecord.beginnerScore.difficulty != 0 &&
                (!isShowingOnlyPlayDataWithScores || songRecord.beginnerScore.score != 0)
            })
        case .normal:
            filteredSongRecords = filteredSongRecords.filter({ songRecord in
                return songRecord.normalScore.difficulty != 0 &&
                (!isShowingOnlyPlayDataWithScores || songRecord.normalScore.score != 0)
            })
        case .hyper:
            filteredSongRecords = filteredSongRecords.filter({ songRecord in
                return songRecord.hyperScore.difficulty != 0 &&
                (!isShowingOnlyPlayDataWithScores || songRecord.hyperScore.score != 0)
            })
        case .another:
            filteredSongRecords = filteredSongRecords.filter({ songRecord in
                return songRecord.anotherScore.difficulty != 0 &&
                (!isShowingOnlyPlayDataWithScores || songRecord.anotherScore.score != 0)
            })
        case .leggendaria:
            filteredSongRecords = filteredSongRecords.filter({ songRecord in
                return songRecord.leggendariaScore.difficulty != 0 &&
                (!isShowingOnlyPlayDataWithScores || songRecord.leggendariaScore.score != 0)
            })
        default: break
        }

        // Sort song records
        if !(levelToShow == .all || levelToShow == .unknown) {
            switch sortMode {
            case .title: break
            case .clearType:
                switch levelToShow {
                case .beginner:
                    filteredSongRecords = filteredSongRecords.sorted { lhs, rhs in
                        return clearTypes.firstIndex(of: lhs.beginnerScore.clearType) ?? 0 <
                            clearTypes.firstIndex(of: rhs.beginnerScore.clearType) ?? 1
                    }
                case .normal:
                    filteredSongRecords = filteredSongRecords.sorted { lhs, rhs in
                        return clearTypes.firstIndex(of: lhs.normalScore.clearType) ?? 0 <
                            clearTypes.firstIndex(of: rhs.normalScore.clearType) ?? 1
                    }
                case .hyper:
                    filteredSongRecords = filteredSongRecords.sorted { lhs, rhs in
                        return clearTypes.firstIndex(of: lhs.hyperScore.clearType) ?? 0 <
                            clearTypes.firstIndex(of: rhs.hyperScore.clearType) ?? 1
                    }
                case .another:
                    filteredSongRecords = filteredSongRecords.sorted { lhs, rhs in
                        return clearTypes.firstIndex(of: lhs.anotherScore.clearType) ?? 0 <
                            clearTypes.firstIndex(of: rhs.anotherScore.clearType) ?? 1
                    }
                case .leggendaria:
                    filteredSongRecords = filteredSongRecords.sorted { lhs, rhs in
                        return clearTypes.firstIndex(of: lhs.leggendariaScore.clearType) ?? 0 <
                            clearTypes.firstIndex(of: rhs.leggendariaScore.clearType) ?? 1
                    }
                default: break
                }
            case .difficulty:
                switch levelToShow {
                case .beginner:
                    filteredSongRecords = filteredSongRecords.sorted { lhs, rhs in
                        return lhs.beginnerScore.difficulty < rhs.beginnerScore.difficulty
                    }
                case .normal:
                    filteredSongRecords = filteredSongRecords.sorted { lhs, rhs in
                        return lhs.normalScore.difficulty < rhs.normalScore.difficulty
                    }
                case .hyper:
                    filteredSongRecords = filteredSongRecords.sorted { lhs, rhs in
                        return lhs.hyperScore.difficulty < rhs.hyperScore.difficulty
                    }
                case .another:
                    filteredSongRecords = filteredSongRecords.sorted { lhs, rhs in
                        return lhs.anotherScore.difficulty < rhs.anotherScore.difficulty
                    }
                case .leggendaria:
                    filteredSongRecords = filteredSongRecords.sorted { lhs, rhs in
                        return lhs.leggendariaScore.difficulty < rhs.leggendariaScore.difficulty
                    }
                default: break
                }
            }
        }

        return filteredSongRecords
    }
    // swiftlint:enable cyclomatic_complexity

    func score(for songRecord: IIDXSongRecord) -> IIDXLevelScore? {
        switch levelToShow {
        case .beginner: return songRecord.beginnerScore
        case .normal: return songRecord.normalScore
        case .hyper: return songRecord.hyperScore
        case .another: return songRecord.anotherScore
        case .leggendaria: return songRecord.leggendariaScore
        default: return nil
        }
    }

    static func latestAvailableIIDXSongRecords(in modelContext: ModelContext,
                                               using calendar: CalendarManager) -> [IIDXSongRecord] {
        let importGroupsForSelectedDate: [ImportGroup] = (try? modelContext.fetch(
            FetchDescriptor<ImportGroup>(
                predicate: importGroups(in: calendar),
                sortBy: [SortDescriptor(\.importDate, order: .forward)]
            )
        )) ?? []
        var importGroupID: String?
        if let importGroupForSelectedDate = importGroupsForSelectedDate.first {
            // Use selected date's import group
            importGroupID = importGroupForSelectedDate.id
        } else {
            // Use latest available import group
            let allImportGroups: [ImportGroup] = (try? modelContext.fetch(
                FetchDescriptor<ImportGroup>(
                    sortBy: [SortDescriptor(\.importDate, order: .forward)]
                )
            )) ?? []
            var importGroupClosestToTheSelectedDate: ImportGroup?
            for importGroup in allImportGroups {
                if importGroup.importDate <= calendar.selectedDate {
                    importGroupClosestToTheSelectedDate = importGroup
                } else {
                    break
                }
            }
            if let importGroupClosestToTheSelectedDate {
                importGroupID = importGroupClosestToTheSelectedDate.id
            }
        }
        if let importGroupID {
            let songRecordsInImportGroup: [IIDXSongRecord] = (try? modelContext.fetch(
                FetchDescriptor<IIDXSongRecord>(
                    predicate: iidxSongRecords(inImportGroupWithID: importGroupID),
                    sortBy: [SortDescriptor(\.title, order: .forward)]
                )
            )) ?? []
            return songRecordsInImportGroup
        }
        return []
    }
}
