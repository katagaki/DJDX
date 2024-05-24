//
//  ScoreSection.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import SwiftUI

struct ScoreSection: View {

    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var levelScore: ScoreForLevel

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8.0) {
                if levelScore.djLevel != "---" {
                    Text(levelScore.djLevel)
                        .font(.largeTitle)
                        .fontWidth(.expanded)
                        .fontWeight(.black)
                        .foregroundStyle(.cyan)
                    Divider()
                    Group {
                        HStack {
                            Text("CLEAR TYPE")
                                .fontWidth(.expanded)
                            Spacer()
                            Text(levelScore.clearType)
                                .foregroundStyle(clearTypeColor())
                        }
                        HStack {
                            Text("DJ LEVEL")
                                .fontWidth(.expanded)
                            Spacer()
                            Text(levelScore.djLevel)
                        }
                        HStack {
                            Text("SCORE")
                                .fontWidth(.expanded)
                            Spacer()
                            Text(String(levelScore.score))
                                .foregroundStyle(.cyan)
                        }
                        HStack {
                            Text("MISS COUNT")
                                .fontWidth(.expanded)
                            Spacer()
                            Text(String(levelScore.missCount))
                                .foregroundStyle(.cyan)
                        }
                    }
                    .bold()
                    .font(.caption)
                } else {
                    Text("現バージョンのプレー記録はありません。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if levelScore.clearType != "NO PLAY" {
                        Divider()
                        HStack {
                            Text("CLEAR TYPE")
                                .fontWidth(.expanded)
                            Spacer()
                            Text(levelScore.clearType)
                                .foregroundStyle(clearTypeColor())
                        }
                        .bold()
                        .font(.caption)
                    }
                }
            }
        } header: {
            SingleLevelLabel(orientation: .horizontal, levelType: levelScore.level, score: levelScore)
        }
    }

    func clearTypeColor() -> any ShapeStyle {
        switch levelScore.clearType {
        case "FULLCOMBO CLEAR": return LinearGradient(
            gradient: Gradient(colors: [.cyan, (colorScheme == .dark ? .white : .blue), .purple]),
            startPoint: .top,
            endPoint: .bottom
        )
        case "FAILED": return Color.red
        case "ASSIST CLEAR": return Color.purple
        case "EASY CLEAR": return Color.green
        case "CLEAR": return Color.cyan
        case "HARD CLEAR": return Color.pink
        case "EX HARD CLEAR": return Color.yellow
        default: return Color.primary
        }
    }
}
