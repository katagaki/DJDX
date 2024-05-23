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
            .task {
                let fetchDescriptor = FetchDescriptor<IIDXSongRecord>(
                    predicate: iidxSongRecords(in: calendar),
                    sortBy: [SortDescriptor(\.title, order: .forward)]
                )
                withAnimation(.snappy.speed(2.0)) {
                    songRecords = (try? modelContext.fetch(fetchDescriptor)) ?? []
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
}
