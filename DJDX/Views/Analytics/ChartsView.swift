//
//  ChartsView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import Charts
import Komponents
import SwiftData
import SwiftUI

struct ChartsView: View {

    @Environment(\.modelContext) var modelContext
    @Query var songRecords: [EPOLISSongRecord]

    @AppStorage(wrappedValue: 1, "SelectedLevelFilterForScoreRateInAnalyticsView") var levelFilterForScoreRate: Int

    let orderOfScoreRates: [String] = ["F", "E", "D", "C", "B", "A", "AA", "AAA"]

    var body: some View {
        List {
            Section {
                Chart(songRecords) { songRecord in
                    let scores: [ScoreForLevel] = [songRecord.beginnerScore,
                                                   songRecord.normalScore,
                                                   songRecord.hyperScore,
                                                   songRecord.anotherScore,
                                                   songRecord.leggendariaScore]
                    ForEach(scores, id: \.level.rawValue) { score in
                        if score.difficulty != 0 {
                            BarMark(
                                x: .value("LEVEL", score.difficulty),
                                y: .value("CLEAR COUNT", score.clearType != "NO PLAY" ? 1 : 0),
                                width: .fixed(10.0)
                            )
                            .foregroundStyle(
                                by: .value("CLEAR TYPE", score.clearType)
                            )
                            .position(
                                by: .value("CLEAR TYPE", score.clearType),
                                axis: .horizontal,
                                span: .ratio(1)
                            )
                        }
                    }
                }
                .chartLegend(.visible)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 13))
                }
                .chartXScale(domain: 1...12)
                .chartForegroundStyleScale([
                    "FULLCOMBO CLEAR": .white,
                    "FAILED": .red,
                    "ASSIST CLEAR": .purple,
                    "EASY CLEAR": .green,
                    "CLEAR": .cyan,
                    "HARD CLEAR": .pink,
                    "EX HARD CLEAR": .yellow,
                    "NO PLAY": .gray
                ])
                .frame(height: 200.0)
                .listRowInsets(.init(top: 18.0, leading: 18.0, bottom: 18.0, trailing: 18.0))
            } header: {
                ListSectionHeader(text: "クリアランプ")
                    .font(.body)
            }
            Section {
                Picker(selection: $levelFilterForScoreRate) {
                    Text("LEVEL 1").tag(1)
                    Text("LEVEL 2").tag(2)
                    Text("LEVEL 3").tag(3)
                    Text("LEVEL 4").tag(4)
                    Text("LEVEL 5").tag(5)
                    Text("LEVEL 6").tag(6)
                    Text("LEVEL 7").tag(7)
                    Text("LEVEL 8").tag(8)
                    Text("LEVEL 9").tag(9)
                    Text("LEVEL 10").tag(10)
                    Text("LEVEL 11").tag(11)
                    Text("LEVEL 12").tag(12)
                } label: {
                    Text("レベル")
                }
                Chart(songRecords) { songRecord in
                    let scores: [ScoreForLevel] = [songRecord.beginnerScore,
                                                   songRecord.normalScore,
                                                   songRecord.hyperScore,
                                                   songRecord.anotherScore,
                                                   songRecord.leggendariaScore]
                    ForEach(scores, id: \.level.rawValue) { score in
                        if score.difficulty != 0 &&
                            score.difficulty == levelFilterForScoreRate &&
                            score.djLevel != "---" {
                            BarMark(
                                x: .value("LEVEL", score.djLevel),
                                y: .value("CLEAR COUNT", score.clearType != "NO PLAY" ? 1 : 0),
                                width: .fixed(10.0)
                            )
                        }
                    }
                }
                .chartLegend(.visible)
                .chartXScale(domain: orderOfScoreRates)
                .frame(height: 200.0)
                .listRowInsets(.init(top: 18.0, leading: 18.0, bottom: 18.0, trailing: 18.0))
            } header: {
                ListSectionHeader(text: "スコアレート")
                    .font(.body)
            }
        }
    }
}
