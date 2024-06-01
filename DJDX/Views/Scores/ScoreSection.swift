//
//  ScoreSection.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import SwiftUI

struct ScoreSection: View {

    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var levelScore: IIDXLevelScore

    var body: some View {
        Section {
            if levelScore.djLevel != "---" {
                Group {
                    switch colorScheme {
                    case .light:
                        Text(levelScore.djLevel)
                            .foregroundStyle(.cyan)
                    case .dark:
                        Text(levelScore.djLevel)
                            .foregroundStyle(LinearGradient(colors: [.white, .cyan],
                                                            startPoint: .top,
                                                            endPoint: .bottom))
                            .drawingGroup()
                            .shadow(color: .cyan, radius: 5.0)
                    @unknown default:
                        Text(levelScore.djLevel)
                    }
                }
                .font(.largeTitle)
                .fontWidth(.expanded)
                .fontWeight(.black)
            } else {
                Text("現バージョンのプレー記録はありません。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if levelScore.djLevel != "---" {
                VStack(alignment: .leading, spacing: 8.0) {
                    ScoreRow("CLEAR TYPE", value: levelScore.clearType, style: clearTypeStyle())
                    ScoreRow("SCORE", value: levelScore.score, style: scoreStyle())
                    ScoreRow("MISS COUNT", value: levelScore.missCount, style: scoreStyle())
                }
                VStack(alignment: .leading, spacing: 8.0) {
                    ScoreRow("PERFECT GREAT", value: levelScore.perfectGreatCount, style: scoreStyle())
                    ScoreRow("GREAT", value: levelScore.greatCount, style: scoreStyle())
                    ScoreRow("MISS", value: levelScore.missCount, style: scoreStyle())
                }
            } else {
                if levelScore.clearType != "NO PLAY" {
                    ScoreRow("CLEAR TYPE", value: levelScore.clearType, style: clearTypeStyle())
                }
            }
        } header: {
            IIDXLevelLabel(orientation: .horizontal, levelType: levelScore.level, score: levelScore)
        }
    }

    func clearTypeStyle() -> any ShapeStyle {
        switch levelScore.clearType {
        case "FULLCOMBO CLEAR":
            return LinearGradient(gradient: Gradient(colors: [.cyan,
                                                              (colorScheme == .dark ? .white : .blue),
                                                              .purple]),
                                  startPoint: .top,
                                  endPoint: .bottom)
        case "FAILED":
            return LinearGradient(gradient: Gradient(colors: [.orange,
                                                              .red,
                                                              .orange]),
                                  startPoint: .top,
                                  endPoint: .bottom)
        case "ASSIST CLEAR":
            return LinearGradient(gradient: Gradient(colors: [(colorScheme == .dark ? .white : .indigo),
                                                              .purple,
                                                              (colorScheme == .dark ? .white : .indigo)]),
                                  startPoint: .top,
                                  endPoint: .bottom)
        case "EASY CLEAR":
            return LinearGradient(gradient: Gradient(colors: [(colorScheme == .dark ? .white : .mint),
                                                              .green,
                                                              .mint]),
                                  startPoint: .top,
                                  endPoint: .bottom)
        case "CLEAR":
            return LinearGradient(gradient: Gradient(colors: [(colorScheme == .dark ? .white : .blue),
                                                              .cyan,
                                                              .blue]),
                                  startPoint: .top,
                                  endPoint: .bottom)
        case "HARD CLEAR":
            return LinearGradient(gradient: Gradient(colors: [(colorScheme == .dark ? .white : .red),
                                                              .pink,
                                                              (colorScheme == .dark ? .white : .red)]),
                                  startPoint: .top,
                                  endPoint: .bottom)
        case "EX HARD CLEAR":
            return LinearGradient(gradient: Gradient(colors: [(colorScheme == .dark ? .white : .orange),
                                                              .yellow,
                                                              (colorScheme == .dark ? .white : .orange)]),
                                  startPoint: .top,
                                  endPoint: .bottom)
        default: return Color.primary
        }
    }

    func scoreStyle() -> any ShapeStyle {
        return LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom)
    }
}
