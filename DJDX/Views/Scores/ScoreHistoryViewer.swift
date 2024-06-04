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

    @State var debugIsAlertShowing: Bool = false
    @State var debugSongRecordsWithoutImportGroup: Int = 0

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
        .refreshable {
            if dataState == .initializing {
                dataState = .loading

                // Get note count
                if let song = allSongNoteCounts[songTitle],
                   let noteCount = song.noteCount(for: level) {
                    totalNoteCount = noteCount
                }

                // Get list of scores
                songRecordsForSong = (try? modelContext.fetch(
                    FetchDescriptor<IIDXSongRecord>(
                        predicate: #Predicate<IIDXSongRecord> {
                            $0.title == songTitle
                        },
                        sortBy: [SortDescriptor(\.importGroup?.importDate, order: .forward)]
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

                // Get date range for scales
                earliestDate = songRecordsForSong.first?.importGroup?.importDate
                latestDate = songRecordsForSong.last?.importGroup?.importDate

                // Dictionarize list of scores
                scoreHistory = songRecordsForSong.reduce(into: [:] as [Date: Int], { partialResult, songRecord in
                    if let importGroup = songRecord.importGroup, let score = songRecord.score(for: level) {
                        partialResult[importGroup.importDate] = score.score
                    }
                })
                scoreRateHistory = songRecordsForSong.reduce(into: [:] as [Date: Float], { partialResult, songRecord in
                    if let importGroup = songRecord.importGroup,
                       let score = songRecord.score(for: level),
                       let totalNoteCount {
                        partialResult[importGroup.importDate] = Float(score.score) / Float(totalNoteCount * 2)
                    }
                })

                withAnimation(.snappy.speed(2.0)) {
                    dataState = .presenting
                }
            }
        }
        .toolbar {
            Menu {
                Button {
                    if let song = allSongNoteCounts[songTitle],
                       let noteCount = song.noteCount(for: level) {
                        totalNoteCount = noteCount
                    }
                } label: {
                    Text(verbatim: "1. Get Note Count")
                }
                Button {
                    songRecordsForSong = (try? modelContext.fetch(
                        FetchDescriptor<IIDXSongRecord>(
                            predicate: #Predicate<IIDXSongRecord> {
                                $0.title == songTitle
                            },
                            sortBy: [SortDescriptor(\.importGroup?.importDate, order: .forward)]
                        )
                    )) ?? []
                } label: {
                    Text(verbatim: "2. Get Song Records")
                }
                Button {
                    songRecordsForSong = (try? modelContext.fetch(
                        FetchDescriptor<IIDXSongRecord>(
                            predicate: #Predicate<IIDXSongRecord> {
                                $0.title == songTitle && $0.importGroup != nil
                            }
                        )
                    )) ?? []
                } label: {
                    Text(verbatim: "2. Get Song Records (Predicate Check For Nil)")
                }
                Button {
                    songRecordsForSong = (try? modelContext.fetch(
                        FetchDescriptor<IIDXSongRecord>(
                        )
                    )) ?? []
                } label: {
                    Text(verbatim: "2. Get Song Records (Non Predicate)")
                }
                Button {
                    songRecordsForSong = songRecordsForSong.compactMap { songRecord in
                        if songRecord.importGroup != nil {
                            return songRecord
                        } else {
                            return nil
                        }
                    }
                } label: {
                    Text(verbatim: "3. Remove Orphaned Scores")
                }
                Button {
                    earliestDate = songRecordsForSong.first?.importGroup?.importDate
                    latestDate = songRecordsForSong.last?.importGroup?.importDate
                } label: {
                    Text(verbatim: "4. Get Date Range For Scales")
                }
                Button {
                    scoreHistory = songRecordsForSong.reduce(into: [:] as [Date: Int], { partialResult, songRecord in
                        if let importGroup = songRecord.importGroup, let score = songRecord.score(for: level) {
                            partialResult[importGroup.importDate] = score.score
                        }
                    })
                } label: {
                    Text(verbatim: "5. Get Score History")
                }
                Button {
                    scoreRateHistory = songRecordsForSong.reduce(
                        into: [:] as [Date: Float], { partialResult, songRecord in
                        if let importGroup = songRecord.importGroup,
                           let score = songRecord.score(for: level),
                           let totalNoteCount {
                            partialResult[importGroup.importDate] = Float(score.score) / Float(totalNoteCount * 2)
                        }
                    })
                } label: {
                    Text(verbatim: "6. Get Score Rate History")
                }
                Divider()
                Button {
                    let songRecordsWithoutImportGroup = (try? modelContext.fetch(
                        FetchDescriptor<IIDXSongRecord>(
                            predicate: #Predicate<IIDXSongRecord> {
                                $0.importGroup == nil
                            }
                        )
                    )) ?? []
                    debugSongRecordsWithoutImportGroup = songRecordsWithoutImportGroup.count
                    debugIsAlertShowing = true
                } label: {
                    Text(verbatim: "Song Records Without Import Group")
                }
                Button(role: .destructive) {
                    let songRecordsWithoutImportGroup = (try? modelContext.fetch(
                        FetchDescriptor<IIDXSongRecord>(
                            predicate: #Predicate<IIDXSongRecord> {
                                $0.importGroup == nil
                            }
                        )
                    )) ?? []
                    for songRecord in songRecordsWithoutImportGroup {
                        modelContext.delete(songRecord)
                    }
                } label: {
                    Text(verbatim: "Delete Song Records Without Import Group")
                }
            } label: {
                Image(systemName: "ladybug")
            }
        }
        .alert(String(debugSongRecordsWithoutImportGroup), isPresented: $debugIsAlertShowing) {
            Button {
                // Intentially left empty
            } label: {
                Text("Shared.OK")
            }
        }
    }
}
