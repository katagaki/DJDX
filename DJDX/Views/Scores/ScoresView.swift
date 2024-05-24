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
    @AppStorage(wrappedValue: true, "LevelShowcaseVisibleInScoresView") var isLevelShowcaseVisible: Bool
    @AppStorage(wrappedValue: true, "GenreVisibleInScoresView") var isGenreVisible: Bool

    @State var dataState: DataState = .initializing

    var body: some View {
        NavigationStack(path: $navigationManager[.scores]) {
            List {
                ForEach(songRecords.filter({ songRecord in
                    if let importGroup = songRecord.importGroup, let songRecordImportGroup = songRecord.importGroup,
                       Calendar.current.isDate(importGroup.importDate, inSameDayAs: songRecordImportGroup.importDate) {
                        if searchTerm.trimmingCharacters(in: .whitespaces) == "" {
                            return true
                        } else {
                            let searchTermTrimmed = searchTerm.lowercased().trimmingCharacters(in: .whitespaces)
                            return songRecord.title.lowercased().contains(searchTermTrimmed) ||
                                   songRecord.artist.lowercased().contains(searchTermTrimmed)
                        }
                    }
                    return false
                })) { songRecord in
                    NavigationLink(value: ViewPath.scoreViewer(songRecord: songRecord)) {
                        VStack(alignment: .leading, spacing: 4.0) {
                            VStack(alignment: .leading, spacing: 2.0) {
                                DetailedSongTitle(songRecord: songRecord,
                                                  isGenreVisible: $isGenreVisible)
                            }
                            .id(songRecord.title)
                            if isLevelShowcaseVisible {
                                HStack {
                                    Spacer()
                                    LevelShowcase(songRecord: songRecord)
                                }
                                .frame(alignment: .top)
                            }
                        }
                    }
                }
            }
            .navigationTitle("譜面一覧")
            .listStyle(.plain)
            .searchable(text: $searchTerm, placement: .navigationBarDrawer(displayMode: .always), prompt: "曲名、アーティスト名")
            .refreshable {
                reloadScores()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Text("表示設定")
                        Picker("レベル", selection: $isLevelShowcaseVisible) {
                            Text("表示")
                                .tag(true)
                            Text("非表示")
                                .tag(false)
                        }
                        .pickerStyle(.menu)
                        Picker("ジャンル", selection: $isGenreVisible) {
                            Text("表示")
                                .tag(true)
                            Text("非表示")
                                .tag(false)
                        }
                        .pickerStyle(.menu)
                    } label: {
                        Image(systemName: "gearshape")
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
