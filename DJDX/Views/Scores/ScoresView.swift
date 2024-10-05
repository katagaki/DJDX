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

    @State var dataState: DataState = .initializing

    @AppStorage(wrappedValue: .single, "ScoresView.PlayTypeFilter") var playTypeToShow: IIDXPlayType
    @AppStorage(wrappedValue: true, "ScoresView.ScoreAvailableOnlyFilter") var isShowingOnlyPlayDataWithScores: Bool
    @AppStorage(wrappedValue: .all, "ScoresView.DifficultyFilter") var difficultyToShow: IIDXDifficulty
    @AppStorage(wrappedValue: .all, "ScoresView.LevelFilter") var levelToShow: IIDXLevel
    @AppStorage(wrappedValue: .all, "ScoresView.ClearTypeFilter") var clearTypeToShow: IIDXClearType
    @AppStorage(wrappedValue: .title, "ScoresView.SortOrder") var sortMode: SortMode

    @State var songRecords: [IIDXSongRecord]?
    @State var songRecordClearRates: [IIDXSongRecord: [IIDXLevel: Float]] = [:]

    @State var songCompactTitles: [String: PersistentIdentifier] = [:]
    @State var songNoteCounts: [String: IIDXNoteCount] = [:]

    @State var playDataDate: Date = .now
    @State var searchTerm: String = ""
    @State var isSystemChangingFilterAndSort: Bool = false
    @State var isSystemChangingCalendarDate: Bool = false
    @State var isSystemChangingAllRecords: Bool = false

    var isTimeTravellingKey: String = "ScoresView.IsTimeTravelling"
    @State var isTimeTravelling: Bool

    var conditionsForReload: [String] {
        [isShowingOnlyPlayDataWithScores.description,
         String(difficultyToShow.rawValue),
         levelToShow.rawValue,
         clearTypeToShow.rawValue,
         searchTerm,
         sortMode.rawValue]
    }

    init() {
        self.isTimeTravelling = UserDefaults.standard.bool(forKey: isTimeTravellingKey)
    }

    var body: some View {
        NavigationStack(path: $navigationManager[.scores]) {
            List {
                ForEach((songRecords ?? []), id: \.title) { songRecord in
                    NavigationLink(value: ViewPath.scoreViewer(songRecord: songRecord)) {
                        ScoreRow(
                            songRecord: songRecord,
                            scoreRate: scoreRate(for: songRecord, of: levelToShow, or: difficultyToShow),
                            levelToShow: $levelToShow,
                            difficultyToShow: $difficultyToShow
                        )
                    }
                    .listRowInsets(.init(top: 0.0, leading: 0.0, bottom: 0.0, trailing: 20.0))
                }
            }
            .navigationTitle("ViewTitle.Scores")
            .navigationBarTitleDisplayMode(.inline)
            .listStyle(.plain)
            .toolbarBackground(.hidden, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Spacer()
                }
                ToolbarItem(placement: .topBarLeading) {
                    LargeInlineTitle("ViewTitle.Scores")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if dataState == .initializing || dataState == .loading {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0.0) {
                TabBarAccessory(placement: .bottom) {
                    VStack(spacing: 8.0) {
                        if isTimeTravelling {
                            DatePicker("Shared.SelectDate",
                                       selection: $playDataDate.animation(.snappy.speed(2.0)),
                                       in: ...Date.now,
                                       displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .padding([.leading, .trailing], 16.0)
                            .padding([.top], 12.0)
                        }
                        ScrollView(.horizontal) {
                            HStack(spacing: 8.0) {
                                PlayTypePicker(playTypeToShow: $playTypeToShow)
                                ScoreSortAndFilter(isShowingOnlyPlayDataWithScores: $isShowingOnlyPlayDataWithScores,
                                                   difficultyToShow: $difficultyToShow,
                                                   levelToShow: $levelToShow,
                                                   clearTypeToShow: $clearTypeToShow,
                                                   sortMode: $sortMode,
                                                   isSystemChangingFilterAndSort: $isSystemChangingFilterAndSort) {
                                    reloadDisplay()
                                }
                                ToolbarButton("Shared.ShowPastData", icon: "arrowshape.turn.up.backward.badge.clock",
                                              isSecondary: !isTimeTravelling) {
                                    withAnimation {
                                        isTimeTravelling.toggle()
                                    }
                                    if !isTimeTravelling {
                                        playDataDate = .now
                                    }
                                }
                            }
                            .padding([.leading, .trailing], 16.0)
                            .padding([.top, .bottom], 12.0)
                        }
                        .scrollIndicators(.hidden)
                    }
                }
            }
            .background {
                switch dataState {
                case .presenting:
                    if songRecords == nil {
                        ContentUnavailableView("Shared.NoData", systemImage: "questionmark.square.dashed")
                    } else {
                        Color.clear
                    }
                default: Color.clear
                }
            }
            .searchable(text: $searchTerm,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Scores.Search.Prompt")
            .refreshable {
                reloadDisplay()
            }
            .onAppear {
                if dataState == .initializing {
                    if !isTimeTravelling {
                        isSystemChangingCalendarDate = true
                        playDataDate = .now
                        isSystemChangingCalendarDate = false
                    }
                    reloadDisplay()
                }
            }
            .onChange(of: playTypeToShow) { _, _ in
                if navigationManager.selectedTab == .scores {
                    reloadDisplay()
                } else {
                    dataState = .initializing
                }
            }
            .onChange(of: conditionsForReload) {_, _ in
                if !isSystemChangingFilterAndSort {
                    reloadDisplay()
                }
            }
            .onChange(of: isTimeTravelling) { _, newValue in
                UserDefaults.standard.set(newValue, forKey: isTimeTravellingKey)
                if !isTimeTravelling {
                    playDataDate = .now
                }
            }
            .onChange(of: playDataDate) { oldValue, newValue in
                if !isSystemChangingCalendarDate,
                   !Calendar.current.isDate(oldValue, inSameDayAs: newValue) {
                    reloadDisplay()
                }
            }
            .navigationDestination(for: ViewPath.self) { viewPath in
                switch viewPath {
                case .scoreViewer(let songRecord):
                    ScoreViewer(songRecord: songRecord,
                                noteCount: noteCount)
                case .scoreHistory(let songTitle, let level, let noteCount):
                    ScoreHistoryViewer(songTitle: songTitle,
                                       level: level,
                                       noteCount: noteCount)
                case .textageViewer(let songTitle, let level, let playSide, let playType):
                    TextageViewer(songTitle: songTitle, level: level, playSide: playSide, playType: playType)
                default: Color.clear
                }
            }
        }
    }

    func reloadDisplay() {
        withAnimation(.snappy.speed(2.0)) {
            dataState = .loading
        } completion: {
            Task.detached {
                let actor = DataFetcher(modelContainer: sharedModelContainer)
                let songRecordIdentifiers = await actor.songRecords(
                    on: playDataDate,
                    filters: FilterOptions(
                        playType: playTypeToShow,
                        onlyPlayDataWithScores: isShowingOnlyPlayDataWithScores,
                        level: levelToShow,
                        difficulty: difficultyToShow,
                        clearType: clearTypeToShow,
                        searchTerm: searchTerm
                    ),
                    sortOptions: SortOptions(
                        mode: sortMode
                    )
                )
                let songCompactTitles = await actor.songCompactTitles()
                let songNoteCounts = await actor.songNoteCounts()

                await MainActor.run {
                    withAnimation(.snappy.speed(2.0)) {
                        if let songRecordIdentifiers {

                            // Get song records
                            let songRecords = songRecordIdentifiers.compactMap {
                                modelContext.model(for: $0) as? IIDXSongRecord
                            }

                            // Calculate clear rates
                            let songRecordClearRates: [IIDXSongRecord: [IIDXLevel: Float]] = songRecords
                                .reduce(into: [:], { partialResult, songRecord in
                                    let song = songNoteCounts[songRecord.titleCompact()]
                                    if let song {
                                        let scores: [IIDXLevelScore] = songRecord.scores()
                                        let scoreRates = scores.reduce(into: [:] as [IIDXLevel: Float]) { partialResult, score in
                                            if let noteCount = song.noteCount(for: score.level) {
                                                partialResult[score.level] = Float(score.score) / Float(noteCount * 2)
                                            }
                                        }
                                        partialResult[songRecord] = scoreRates
                                    }
                                })

                            self.songRecordClearRates = songRecordClearRates
                            self.songRecords = songRecords
                        } else {
                            self.songRecords = nil
                        }

                        self.songCompactTitles = songCompactTitles
                        self.songNoteCounts = songNoteCounts

                        dataState = .presenting
                    }
                }
            }
        }
    }

    func scoreRate(for songRecord: IIDXSongRecord, of level: IIDXLevel, or difficulty: IIDXDifficulty) -> Float? {
        return songRecordClearRates[songRecord]?[
            songRecord.level(for: level, or: difficulty)]
    }

    func noteCount(for songRecord: IIDXSongRecord, of level: IIDXLevel) -> Int? {
        let compactTitle = songRecord.titleCompact()
        let keyPath: KeyPath<IIDXNoteCount, Int?>?
        switch level {
        case .beginner: keyPath = \.beginnerNoteCount
        case .normal: keyPath = \.normalNoteCount
        case .hyper: keyPath = \.hyperNoteCount
        case .another: keyPath = \.anotherNoteCount
        case .leggendaria: keyPath = \.leggendariaNoteCount
        default: keyPath = nil
        }
        if let keyPath,
           let songIdentifier = songCompactTitles[compactTitle],
           let song = modelContext.model(for: songIdentifier) as? IIDXSong {
            return song.spNoteCount?[keyPath: keyPath]
        } else {
            return nil
        }
    }
}
