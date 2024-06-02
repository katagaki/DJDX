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

    @State var allSongRecords: [IIDXSongRecord] = []
    @State var filteredSongRecords: [IIDXSongRecord] = []
    @State var sortedSongRecords: [IIDXSongRecord] = []
    @State var displayedSongRecords: [IIDXSongRecord] = []
    @State var dataState: DataState = .initializing

    @AppStorage(wrappedValue: true, "ScoresView.ScoreAvailableOnlyFilter") var isShowingOnlyPlayDataWithScores: Bool
    @AppStorage(wrappedValue: .all, "ScoresView.LevelFilter") var levelToShow: IIDXLevel
    @AppStorage(wrappedValue: .all, "ScoresView.DifficultyFilter") var difficultyToShow: IIDXDifficulty

    @AppStorage(wrappedValue: .title, "ScoresView.SortOrder") var sortMode: SortMode

    @State var searchTerm: String = ""

    var body: some View {
        NavigationStack(path: $navigationManager[.scores]) {
            List {
                ForEach(displayedSongRecords, id: \.title) { songRecord in
                    NavigationLink(value: ViewPath.scoreViewer(songRecord: songRecord)) {
                        ScoreRow(
                            songRecord: songRecord,
                            levelToShow: $levelToShow,
                            difficultyToShow: $difficultyToShow
                        )
                    }
                    .padding([.top, .bottom], 8.0)
                    .listRowInsets(.init(top: 0.0, leading: 0.0, bottom: 0.0, trailing: 20.0))
                    .safeAreaInset(edge: .leading) {
                        VStack {
                            if let score = songRecord.score(for: levelToShow) {
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
                        .modifier(ConditionalShadow(color: .black.opacity(0.2), radius: 1.0, x: 2.0))
                    }
                }
            }
            .navigationTitle("ViewTitle.Scores")
            .listStyle(.plain)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Menu("Shared.Sort") {
                            Picker("Shared.Sort", selection: $sortMode) {
                                if levelToShow != .all {
                                    ForEach(SortMode.whenLevelFiltered, id: \.self) { sortMode in
                                        Text(LocalizedStringKey(sortMode.rawValue))
                                            .tag(sortMode)
                                    }
                                } else if difficultyToShow != .all {
                                    ForEach(SortMode.whenDifficultyFiltered, id: \.self) { sortMode in
                                        Text(LocalizedStringKey(sortMode.rawValue))
                                            .tag(sortMode)
                                    }
                                } else {
                                    Text(LocalizedStringKey(SortMode.title.rawValue))
                                        .tag(SortMode.title)
                                }
                            }
                            .pickerStyle(.inline)
                        }
                        Menu(
                            "Shared.Filter",
                            systemImage: (levelToShow == .all && difficultyToShow == .all ?
                                          "line.3.horizontal.decrease.circle" :
                                            "line.3.horizontal.decrease.circle.fill")
                        ) {
                            Toggle("Scores.Filter.ShowWithScoreOnly", isOn: $isShowingOnlyPlayDataWithScores)
                            Section("Shared.Filter") {
                                Picker("Shared.Level", selection: $levelToShow) {
                                    ForEach(IIDXLevel.sorted, id: \.self) { sortLevel in
                                        Text(LocalizedStringKey(sortLevel.rawValue))
                                            .tag(sortLevel)
                                    }
                                }
                                Picker("Shared.Difficulty", selection: $difficultyToShow) {
                                    ForEach(IIDXDifficulty.sorted, id: \.self) { sortDifficulty in
                                        Text("LEVEL \(sortDifficulty.rawValue)")
                                            .tag(sortDifficulty)
                                    }
                                }
                                Button("Shared.Filter.ResetAll", systemImage: "arrow.clockwise") {
                                    levelToShow = .all
                                    difficultyToShow = .all
                                    filterSongRecords()
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }
            }
            .overlay {
                switch dataState {
                case .initializing, .loading:
                    ProgressView()
                        .progressViewStyle(.circular)
                case .presenting:
                    if allSongRecords.count == 0 {
                        ContentUnavailableView("Shared.NoData", systemImage: "questionmark.square.dashed")
                    } else {
                        Color.clear
                    }
                }
            }
            .task {
                if dataState == .initializing {
                    reloadAllScores()
                }
            }
            .searchable(text: $searchTerm,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Scores.Search.Prompt")
            .refreshable {
                reloadAllScores()
            }
            .onChange(of: allSongRecords) { _, _ in
                filterSongRecords()
            }
            .onChange(of: filteredSongRecords) { _, _ in
                sortSongRecords()
            }
            .onChange(of: sortedSongRecords) { _, _ in
                searchSongRecords()
            }
            .onChange(of: searchTerm) { _, _ in
                searchSongRecords()
            }
            .onChange(of: levelToShow) { _, newValue in
                if newValue != .all {
                    difficultyToShow = .all
                    filterSongRecords()
                }
            }
            .onChange(of: difficultyToShow) { _, newValue in
                if newValue != .all {
                    levelToShow = .all
                    filterSongRecords()
                }
            }
            .onChange(of: isShowingOnlyPlayDataWithScores) { _, _ in
                filterSongRecords()
            }
            .onChange(of: sortMode) { _, _ in
                sortSongRecords()
            }
            .onChange(of: calendar.selectedDate) { oldValue, newValue in
                if !Calendar.current.isDate(oldValue, inSameDayAs: newValue) {
                    dataState = .initializing
                }
            }
            .navigationDestination(for: ViewPath.self) { viewPath in
                switch viewPath {
                case .scoreViewer(let songRecord):
                    ScoreViewer(songRecord: songRecord)
                case .textageViewer(let songTitle, let level, let playSide):
                    TextageViewer(songTitle: songTitle, level: level, playSide: playSide)
                default: Color.clear
                }
            }
        }
    }
}
