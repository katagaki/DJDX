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
    @State var songRecords: [IIDXSongRecord] = []
    @State var displayedSongRecords: [IIDXSongRecord] = []

    @State var searchTerm: String = ""
    @AppStorage(wrappedValue: false, "ScoresView.ArtistVisible") var isArtistVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.LevelVisible") var isLevelVisible: Bool
    @AppStorage(wrappedValue: false, "ScorewView.GenreVisible") var isGenreVisible: Bool
    @AppStorage(wrappedValue: true, "ScorewView.ScoreVisible") var isScoreVisible: Bool
    @AppStorage(wrappedValue: false, "ScorewView.LastPlayDateVisible") var isLastPlayDateVisible: Bool
    @AppStorage(wrappedValue: .all, "ScoresView.LevelFilter") var levelToShow: IIDXLevel
    @AppStorage(wrappedValue: true, "ScoresView.ScoreAvailableOnlyFilter") var isShowingOnlyPlayDataWithScores: Bool
    @AppStorage(wrappedValue: .title, "ScoresView.SortOrder") var sortMode: SortMode

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
                ForEach(displayedSongRecords, id: \.title) { songRecord in
                    NavigationLink(value: ViewPath.scoreViewer(songRecord: songRecord)) {
                        VStack(alignment: .trailing, spacing: 4.0) {
                            HStack(alignment: .center, spacing: 8.0) {
                                VStack(alignment: .leading, spacing: 2.0) {
                                    if isGenreVisible {
                                        Text(songRecord.genre)
                                            .font(.caption2)
                                            .fontWidth(.condensed)
                                    }
                                    Text(songRecord.title)
                                        .bold()
                                        .fontWidth(.condensed)
                                    if isArtistVisible {
                                        Text(songRecord.artist)
                                            .font(.caption)
                                            .fontWidth(.condensed)
                                    }
                                    if isScoreVisible || isLastPlayDateVisible {
                                        HStack {
                                            if isScoreVisible, let score = score(for: songRecord)?.score, score != 0 {
                                                Text(String(score))
                                                    .foregroundStyle(LinearGradient(colors: [.cyan, .blue],
                                                                                    startPoint: .top,
                                                                                    endPoint: .bottom))
                                                    .font(.caption)
                                                    .fontWeight(.heavy)
                                            }
                                            if isScoreVisible && isLastPlayDateVisible,
                                               score(for: songRecord)?.score != 0 {
                                                Divider()
                                                    .frame(maxHeight: 14.0)
                                            }
                                            if isLastPlayDateVisible {
                                                Text(RelativeDateTimeFormatter().localizedString(
                                                    for: songRecord.lastPlayDate,
                                                    relativeTo: .now
                                                ))
                                                .font(.caption2)
                                                .fontWidth(.condensed)
                                                .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
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
                        .modifier(ConditionalShadow(color: .black.opacity(0.2), radius: 1.0, x: 2.0))
                    }
                }
            }
            .navigationTitle("プレーデータ")
            .listStyle(.plain)
            .searchable(text: $searchTerm,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "曲名、アーティスト名")
            .refreshable {
                reloadDisplayedScores()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        if levelToShow != .all {
                            Menu("並べ替え") {
                                Picker("並べ替え", selection: $sortMode) {
                                    ForEach(SortMode.all, id: \.self) { sortMode in
                                        Text(sortMode.rawValue)
                                            .tag(sortMode)
                                    }
                                }
                                .pickerStyle(.inline)
                            }
                        }
                        Menu("フィルター", systemImage: "line.3.horizontal.decrease.circle") {
                            Toggle("スコアのある曲のみ表示", isOn: $isShowingOnlyPlayDataWithScores)
                            Section("フィルター") {
                                Picker("レベル", selection: $levelToShow) {
                                    ForEach(IIDXLevel.sortLevels, id: \.self) { sortLevel in
                                        Text(sortLevel.rawValue)
                                            .tag(sortLevel)
                                    }
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
                    if songRecords.count == 0 {
                        ContentUnavailableView("該当するデータはありません。", systemImage: "questionmark.square.dashed")
                    } else {
                        Color.clear
                    }
                }
            }
            .task {
                if dataState == .initializing {
                    reloadAllScores()
                    reloadDisplayedScores()
                }
            }
            .onChange(of: searchTerm) { _, _ in
                displayedSongRecords = searchSongRecords(songRecords, searchTerm: searchTerm)
            }
            .onChange(of: levelToShow) { _, _ in
                reloadDisplayedScores()
            }
            .onChange(of: isShowingOnlyPlayDataWithScores) { _, _ in
                reloadDisplayedScores()
            }
            .onChange(of: sortMode) { _, _ in
                withAnimation(.snappy.speed(2.0)) {
                    displayedSongRecords = sortSongRecords(displayedSongRecords)
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
}
