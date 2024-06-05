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

    @Binding var allSongNoteCounts: [String: IIDXNoteCount]
    var songTitle: String
    var level: IIDXLevel

    @State var songRecordsForSong: [IIDXSongRecord] = []
    @State var totalNoteCount: Int?
    @State var scoreHistory: [Date: Int] = [:]
    @State var scoreRateHistory: [Date: Float] = [:]
    @State var earliestDate: Date?
    @State var latestDate: Date?
    @State var dataState: DataState = .initializing

    var body: some View {
        List {
            if let earliestDate, let latestDate, let totalNoteCount {
                Section {
                    Chart(scoreHistory.sorted(by: { $0.key < $1.key }), id: \.key) { date, score in
                        AreaMark(x: .value("Shared.Date", date), y: .value("Shared.Score", score))
                    }
                    .chartXScale(domain: earliestDate...latestDate)
                    .chartYScale(domain: 0...(totalNoteCount * 2))
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
                if earliestDate == nil || latestDate == nil {
                    ContentUnavailableView(
                        "Scores.History.NoData",
                        systemImage: "questionmark.app.dashed"
                    )
                }
            }
        }
    }

    func reloadScoreHistory() {
        // Get note count
        if let song = allSongNoteCounts[songTitle],
           let noteCount = song.noteCount(for: level) {
            totalNoteCount = noteCount
        }

        // Get list of scores
        songRecordsForSong = (try? modelContext.fetch(
            FetchDescriptor<IIDXSongRecord>(
                predicate: #Predicate<IIDXSongRecord> {
                    $0.title == songTitle && $0.importGroup != nil
                }
            )
        )) ?? []

        // Remove orphaned scores
        songRecordsForSong = songRecordsForSong.compactMap { songRecord in
            if songRecord.importGroup != nil {
                return songRecord
            } else {
                return nil
            }
        }

        // Sort song records from earliest to latest
        songRecordsForSong.sort { lhs, rhs in
            if let lhsImportGroup = lhs.importGroup, let rhsImportGroup = rhs.importGroup {
                return lhsImportGroup.importDate < rhsImportGroup.importDate
            } else {
                return false
            }
        }

        // Dictionarize list of scores
        scoreHistory = songRecordsForSong.reduce(into: [:] as [Date: Int], { partialResult, songRecord in
            if let importGroup = songRecord.importGroup, let score = songRecord.score(for: level) {
                partialResult[importGroup.importDate] = score.score
            }
        })
        scoreRateHistory = songRecordsForSong.reduce(
            into: [:] as [Date: Float], { partialResult, songRecord in
            if let importGroup = songRecord.importGroup,
               let score = songRecord.score(for: level),
               let totalNoteCount {
                partialResult[importGroup.importDate] = Float(score.score) / Float(totalNoteCount * 2)
            }
        })

        // Set date range for chart
        if let firstSongRecord = songRecordsForSong.first,
           let lastSongRecord = songRecordsForSong.last,
           let firstImportGroup = firstSongRecord.importGroup,
           let lastImportGroup = lastSongRecord.importGroup {
            let earliestDate = firstImportGroup.importDate
            let latestDate = lastImportGroup.importDate
            if earliestDate < latestDate {
                self.earliestDate = earliestDate
                self.latestDate = latestDate
            }
        }
    }
}
