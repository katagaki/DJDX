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
    @State var filteredSongRecords: [IIDXSongRecord]?

    @State var searchTerm: String = ""
    @AppStorage(wrappedValue: true, "LevelShowcaseVisibleInScoresView") var isLevelShowcaseVisible: Bool
    @AppStorage(wrappedValue: true, "GenreVisibleInScoresView") var isGenreVisible: Bool
    @AppStorage(wrappedValue: "ALL", "DifficultyToFilterByInScoresView") var difficultyToShow: String

    @State var dataState: DataState = .initializing

    var body: some View {
        NavigationStack(path: $navigationManager[.scores]) {
            List {
                ForEach(filteredSongRecords ?? songRecords) { songRecord in
                    NavigationLink(value: ViewPath.scoreViewer(songRecord: songRecord)) {
                        VStack(alignment: .leading, spacing: 4.0) {
                            HStack(alignment: .center, spacing: 8.0) {
                                VStack(alignment: .leading, spacing: 2.0) {
                                    DetailedSongTitle(songRecord: songRecord,
                                                      isGenreVisible: $isGenreVisible)
                                }
                                if isLevelShowcaseVisible && difficultyToShow != "ALL" {
                                    Spacer()
                                    switch difficultyToShow {
                                    case "BEGINNER": SingleLevelLabel(levelType: .beginner, score: songRecord.beginnerScore)
                                    case "NORMAL": SingleLevelLabel(levelType: .normal, score: songRecord.normalScore)
                                    case "HYPER": SingleLevelLabel(levelType: .hyper, score: songRecord.hyperScore)
                                    case "ANOTHER": SingleLevelLabel(levelType: .another, score: songRecord.anotherScore)
                                    case "LEGGENDARIA": SingleLevelLabel(levelType: .leggendaria, score: songRecord.leggendariaScore)
                                    default: Color.clear
                                    }
                                }
                            }
                            if isLevelShowcaseVisible && difficultyToShow == "ALL" {
                                HStack {
                                    Spacer()
                                    LevelShowcase(songRecord: songRecord)
                                }
                                .frame(alignment: .top)
                            }
                        }
                    }
                    .padding([.top, .bottom], 8.0)
                    .listRowInsets(.init(top: 0.0, leading: 0.0, bottom: 0.0, trailing: 20.0))
                    .safeAreaInset(edge: .leading) {
                        Group {
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
                            }
                        }
                        .frame(width: 12.0)
                        .shadow(color: .black.opacity(0.2), radius: 1.0, x: 2.0)
                    }
                }
            }
            .navigationTitle("プレーデータ")
            .listStyle(.plain)
            .searchable(text: $searchTerm.animation(.snappy.speed(2.0)),
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "曲名、アーティスト名")
            .refreshable {
                reloadScores()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker(selection: $difficultyToShow) {
                            Text("すべて")
                                .tag("ALL")
                            Text("BEGINNER")
                                .tag("BEGINNER")
                            Text("NORMAL")
                                .tag("NORMAL")
                            Text("HYPER")
                                .tag("HYPER")
                            Text("ANOTHER")
                                .tag("ANOTHER")
                            Text("LEGGENDARIA")
                                .tag("LEGGENDARIA")
                        } label: {
                            Text("レベル")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .background {
                switch dataState {
                case .initializing, .loading:
                    ProgressView()
                        .progressViewStyle(.circular)
                case .presenting:
                    if songRecords.count == 0 {
                        ContentUnavailableView("選択した日付にプレーデータがありません。", systemImage: "questionmark.square.dashed")
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
            .onChange(of: searchTerm) { _, _ in
                filterSongRecords()
            }
            .onChange(of: difficultyToShow, { _, _ in
                filterSongRecords()
            })
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
        dataState = .loading
        let newSongRecords = ScoresView.latestAvailableIIDXSongRecords(in: modelContext, using: calendar)
        Task.detached {
            await MainActor.run { [newSongRecords] in
                withAnimation(.snappy.speed(2.0)) {
                    songRecords.removeAll()
                    songRecords.append(contentsOf: newSongRecords)
                    dataState = .presenting
                }
            }
        }
    }

    func filterSongRecords() {
        var filteredSongRecords: [IIDXSongRecord] = songRecords
        if searchTerm.trimmingCharacters(in: .whitespaces) != "" {
            filteredSongRecords = filteredSongRecords.filter({ songRecord in
                let searchTermTrimmed = searchTerm.lowercased().trimmingCharacters(in: .whitespaces)
                return songRecord.title.lowercased().contains(searchTermTrimmed) ||
                songRecord.artist.lowercased().contains(searchTermTrimmed)
            })
        } else {
            self.filteredSongRecords = nil
        }
        switch difficultyToShow {
        case "BEGINNER": filteredSongRecords = filteredSongRecords.filter({ $0.beginnerScore.difficulty != 0 })
        case "NORMAL": filteredSongRecords = filteredSongRecords.filter({ $0.normalScore.difficulty != 0 })
        case "HYPER": filteredSongRecords = filteredSongRecords.filter({ $0.hyperScore.difficulty != 0 })
        case "ANOTHER": filteredSongRecords = filteredSongRecords.filter({ $0.anotherScore.difficulty != 0 })
        case "LEGGENDARIA": filteredSongRecords = filteredSongRecords.filter({ $0.leggendariaScore.difficulty != 0 })
        default: break
        }
        self.filteredSongRecords = filteredSongRecords
    }

    func score(for songRecord: IIDXSongRecord) -> ScoreForLevel? {
        switch difficultyToShow {
        case "BEGINNER": return songRecord.beginnerScore
        case "NORMAL": return songRecord.normalScore
        case "HYPER": return songRecord.hyperScore
        case "ANOTHER": return songRecord.anotherScore
        case "LEGGENDARIA": return songRecord.leggendariaScore
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
