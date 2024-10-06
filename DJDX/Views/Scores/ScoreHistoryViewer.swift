//
//  ScoreHistoryViewer.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/04.
//

import Charts
import Komponents
import SwiftData
import SwiftUI

struct ScoreHistoryViewer: View {

    @Environment(\.modelContext) var modelContext

    var percentageFormatter: NumberFormatter

    var songTitle: String
    var level: IIDXLevel
    var noteCount: Int?

    @State var songRecordsForSong: [IIDXSongRecord] = []

    @State var scoreHistory: [Date: Int] = [:]
    @State var scoreRateHistory: [Date: Float] = [:]
    @State var summarizedScoreHistory: [Date: Int] = [:]
    @State var summarizedScoreRateHistory: [Date: Float] = [:]

    @State var earliestDate: Date = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
    @State var latestDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
    @State var dataState: DataState = .initializing

    init(songTitle: String, level: IIDXLevel, noteCount: Int? = nil) {
        self.songTitle = songTitle
        self.level = level
        self.noteCount = noteCount

        percentageFormatter = NumberFormatter()
        percentageFormatter.numberStyle = .percent
        percentageFormatter.minimumIntegerDigits = 1
        percentageFormatter.maximumIntegerDigits = 3
        percentageFormatter.maximumFractionDigits = 0
    }
    var body: some View {
        List {
            if let noteCount, noteCount > 0 {
                Section {
                    Chart {
                        ForEach(scoreHistory.sorted(by: { $0.key < $1.key }), id: \.key) { date, score in
                            AreaMark(x: .value("Shared.Date", date), y: .value("Shared.Score", score))
                        }
                        RuleMark(y: .value("AAA", Float(noteCount * 2) * 8.0 / 9.0))
                            .foregroundStyle(.orange)
                            .annotation(position: .topLeading,
                                        overflowResolution: .init(x: .fit(to: .chart), y: .automatic)) {
                                Text(verbatim: "AAA")
                                    .foregroundStyle(.orange.gradient)
                                    .font(.caption2)
                                    .opacity(0.7)
                            }
                            .opacity(0.7)
                        RuleMark(y: .value("AA", Float(noteCount * 2) * 7.0 / 9.0))
                            .foregroundStyle(.gray)
                            .annotation(position: .topLeading,
                                        overflowResolution: .init(x: .fit(to: .chart), y: .automatic)) {
                                Text(verbatim: "AA")
                                    .foregroundStyle(.gray.gradient)
                                    .font(.caption2)
                                    .opacity(0.55)
                            }
                            .opacity(0.55)
                        RuleMark(y: .value("A", Float(noteCount * 2) * 6.0 / 9.0))
                            .foregroundStyle(.teal)
                            .annotation(position: .topLeading,
                                        overflowResolution: .init(x: .fit(to: .chart), y: .automatic)) {
                                Text(verbatim: "A")
                                    .foregroundStyle(.teal.gradient)
                                    .font(.caption2)
                                    .opacity(0.4)
                            }
                            .opacity(0.4)
                    }
                    .chartXScale(domain: earliestDate...latestDate)
                    .chartYScale(domain: 0...(noteCount * 2))
                    .frame(height: 200.0)
                    .listRowInsets(.init(top: 18.0, leading: 20.0, bottom: 18.0, trailing: 20.0))
                }
                Section {
                    VStack(alignment: .leading, spacing: 8.0) {
                        ForEach(summarizedScoreHistory.sorted(by: {$0.key < $1.key}), id: \.key) { date, score in
                            DetailRow(
                                date.formatted(date: .abbreviated, time: .omitted),
                                value: String(score),
                                style: LinearGradient(
                                    colors: [.cyan, .blue],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                    }
                } header: {
                    ListSectionHeader(text: "Shared.Score")
                        .font(.body)
                }
                Section {
                    VStack(alignment: .leading, spacing: 8.0) {
                        ForEach(summarizedScoreRateHistory.sorted(by: {$0.key < $1.key}), id: \.key) { date, scoreRate in
                            DetailRow(date.formatted(date: .abbreviated, time: .omitted),
                                      value: percentageFormatter.string(from: NSNumber(value: scoreRate)) ?? "0%",
                                      style: LinearGradient(
                                        colors: [.primary.opacity(0.35), .primary.opacity(0.2)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ))
                        }
                    }
                } header: {
                    ListSectionHeader(text: "Shared.ScoreRate")
                        .font(.body)
                }
            }
        }
        .navigationTitle("ViewTitle.Scores.History.\(songTitle)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(alignment: .center, spacing: 2.0) {
                    Text(songTitle)
                        .bold()
                        .fontWidth(.condensed)
                    Text("ViewTitle.Scores.History")
                        .font(.caption)
                        .fontWidth(.condensed)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0.0) {
            TabBarAccessory(placement: .bottom) {
                Color.clear
                    .frame(height: 0.0)
            }
        }
        .task {
            if dataState == .initializing {
                dataState = .loading
                reloadScoreHistory()
                withAnimation(.snappy.speed(2.0)) {
                    dataState = .presenting
                }
            }
        }
        .overlay {
            switch dataState {
            case .initializing, .loading:
                ProgressView()
            case .presenting:
                if noteCount == nil {
                    ContentUnavailableView(
                        "Scores.History.NoData",
                        systemImage: "questionmark.app.dashed",
                        description: Text("Scores.History.NoData.Description")
                    )
                }
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func reloadScoreHistory() {
        // Get list of scores
        songRecordsForSong = (try? modelContext.fetch(
            FetchDescriptor<IIDXSongRecord>(
                predicate: #Predicate<IIDXSongRecord> {
                    $0.title == songTitle && $0.importGroup != nil
                }
            )
        )) ?? []

        // Dictionarize list of scores
        scoreHistory = songRecordsForSong.reduce(into: [:] as [Date: Int], { partialResult, songRecord in
            if let importGroup = songRecord.importGroup,
               let score = songRecord.score(for: level), score.score > 0 {
                partialResult[importGroup.importDate] = score.score
            }
        })

        // Dictionarize list of score rates
        if let noteCount {
            scoreRateHistory = songRecordsForSong.reduce(
                into: [:] as [Date: Float], { partialResult, songRecord in
                    if let importGroup = songRecord.importGroup,
                       let score = songRecord.score(for: level), score.score > 0 {
                        partialResult[importGroup.importDate] = Float(score.score) / Float(noteCount * 2)
                    }
                })
        }

        // Summarize scores
        var previousScore: Int?
        for (date, score) in scoreHistory {
            if let previousScore {
                if score != previousScore {
                    summarizedScoreHistory[date] = score
                }
            } else {
                summarizedScoreHistory[date] = score
            }
            previousScore = score
        }

        // Summarize score rates
        var previousScoreRate: Int?
        for (date, scoreRate) in scoreRateHistory {
            if let previousScoreRate {
                if Int(scoreRate) != previousScoreRate {
                    summarizedScoreRateHistory[date] = scoreRate
                }
            } else {
                summarizedScoreRateHistory[date] = scoreRate
            }
            previousScoreRate = Int(scoreRate)
        }

        // Set date range for chart
        var newEarliestDate: Date = .now
        var newLatestDate: Date = .now
        for songRecord in songRecordsForSong {
            if let score = songRecord.score(for: level), score.score > 0,
               let importGroup = songRecord.importGroup {
                if importGroup.importDate < newEarliestDate {
                    newEarliestDate = importGroup.importDate
                } else if importGroup.importDate > newLatestDate {
                    newLatestDate = importGroup.importDate
                }
            }
        }
        earliestDate = Calendar.current.date(byAdding: .day, value: -1, to: newEarliestDate)!
        latestDate = Calendar.current.date(byAdding: .day, value: 1, to: newLatestDate)!
    }
}
