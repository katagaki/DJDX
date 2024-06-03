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

    @State var totalNoteCount: Int = 0
    @State var scoreHistory: [Date: Int] = [:]
    @State var scoreRateHistory: [Date: Float] = [:]
    @State var earliestDate: Date = .distantPast
    @State var latestDate: Date = .distantFuture
    @State var dataState: DataState = .initializing

    var body: some View {
        List {
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
        .navigationTitle("ViewTitle.Scores.History.\(songTitle)")
        .task {
            if dataState == .initializing {
                dataState = .loading

                // Get note count
                if let song = allSongNoteCounts[songTitle],
                   let noteCount = song.noteCount(for: level) {
                    totalNoteCount = noteCount
                }

                // Get list of scores
                let songRecordsForSong: [IIDXSongRecord] = (try? modelContext.fetch(
                    FetchDescriptor<IIDXSongRecord>(
                        predicate: #Predicate<IIDXSongRecord> {
                            $0.title == songTitle
                        }
                        // TODO: Possible data consistency issue causing this to crash app:
                        // sortBy: [SortDescriptor(\.importGroup?.importDate, order: .forward)]
                    )
                )) ?? []

                // Get date scales
                earliestDate = songRecordsForSong.first?.importGroup?.importDate ?? .distantPast
                latestDate = songRecordsForSong.last?.importGroup?.importDate ?? .distantFuture

                // Dictionarize list of scores
                scoreHistory = songRecordsForSong.reduce(into: [:] as [Date: Int], { partialResult, songRecord in
                    if let importGroup = songRecord.importGroup, let score = songRecord.score(for: level) {
                        partialResult[importGroup.importDate] = score.score
                    }
                })
                scoreRateHistory = songRecordsForSong.reduce(into: [:] as [Date: Float], { partialResult, songRecord in
                    if let importGroup = songRecord.importGroup, let score = songRecord.score(for: level) {
                        partialResult[importGroup.importDate] = Float(score.score) / Float(totalNoteCount * 2)
                    }
                })

                withAnimation(.snappy.speed(2.0)) {
                    dataState = .presenting
                }
            }
        }
    }
}
