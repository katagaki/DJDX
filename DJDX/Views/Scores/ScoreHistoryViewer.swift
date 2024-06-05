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

    var songTitle: String
    var level: IIDXLevel
    var noteCount: Int?

    @State var songRecordsForSong: [IIDXSongRecord] = []
    @State var scoreHistory: [Date: Int] = [:]
    @State var scoreRateHistory: [Date: Float] = [:]
    @State var earliestDate: Date = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
    @State var latestDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
    @State var dataState: DataState = .initializing

    var body: some View {
        List {
            if let noteCount, noteCount > 0 {
                Section {
                    Chart(scoreHistory.sorted(by: { $0.key < $1.key }), id: \.key) { date, score in
                        AreaMark(x: .value("Shared.Date", date), y: .value("Shared.Score", score))
                    }
                    .chartXScale(domain: earliestDate...latestDate)
                    .chartYScale(domain: 0...(noteCount * 2))
                    .frame(height: 200.0)
                    .listRowInsets(.init(top: 18.0, leading: 20.0, bottom: 18.0, trailing: 20.0))
                } header: {
                    ListSectionHeader(text: "Shared.Score")
                        .font(.body)
                }
                Section {
                    Chart(scoreRateHistory.sorted(by: { $0.key < $1.key }), id: \.key) { date, scoreRate in
                        AreaMark(x: .value("Shared.Date", date), y: .value("Shared.ScoreRate", scoreRate * 100.0))
                    }
                    .chartXScale(domain: earliestDate...latestDate)
                    .chartYScale(domain: 0.0...100.0)
                    .frame(height: 200.0)
                    .listRowInsets(.init(top: 18.0, leading: 20.0, bottom: 18.0, trailing: 20.0))
                } header: {
                    ListSectionHeader(text: "Shared.ScoreRate")
                        .font(.body)
                }
            }
        }
        .navigationTitle("ViewTitle.Scores.History.\(songTitle)")
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
                        systemImage: "questionmark.app.dashed"
                    )
                }
            }
        }
    }

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
        if let noteCount {
            scoreRateHistory = songRecordsForSong.reduce(
                into: [:] as [Date: Float], { partialResult, songRecord in
                    if let importGroup = songRecord.importGroup,
                       let score = songRecord.score(for: level), score.score > 0 {
                        partialResult[importGroup.importDate] = Float(score.score) / Float(noteCount * 2)
                    }
                })
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
