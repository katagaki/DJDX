//
//  ScoreSection.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import Komponents
import SwiftUI

struct ScoreSection: View {

    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var songTitle: String
    var score: IIDXLevelScore
    var noteCount: Int?

    var body: some View {
        Section {
            if score.djLevel != "---" {
                HStack {
                    Group {
                        switch colorScheme {
                        case .light:
                            Text(score.djLevel)
                                .foregroundStyle(LinearGradient(colors: [.cyan, .blue],
                                                                startPoint: .top,
                                                                endPoint: .bottom))
                                .modifier(ConditionalShadow(color: .blue.opacity(0.2), radius: 3.0))
                        case .dark:
                            Text(score.djLevel)
                                .foregroundStyle(LinearGradient(colors: [.white, .cyan],
                                                                startPoint: .top,
                                                                endPoint: .bottom))
                                .drawingGroup()
                                .shadow(color: .cyan, radius: 5.0)
                        @unknown default:
                            Text(score.djLevel)
                        }
                        Spacer()
                        if let noteCount {
                            Text(Float(score.score) / Float(noteCount * 2),
                                 format: .percent.precision(.fractionLength(0)))
                            .foregroundStyle(LinearGradient(
                                colors: [.primary.opacity(0.35), .primary.opacity(0.2)],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                        }
                    }
                    .font(.largeTitle)
                    .fontWidth(.expanded)
                    .fontWeight(.black)
                }
            } else {
                Text("Scores.Viewer.NoDataForCurrentVersion")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if score.djLevel != "---" {
                VStack(alignment: .leading, spacing: 8.0) {
                    DetailRow("CLEAR TYPE", value: score.clearType, style: clearTypeStyle())
                    DetailRow("SCORE", value: score.score, style: scoreStyle())
                    DetailRow("MISS COUNT", value: score.missCount, style: scoreStyle())
                }
                VStack(alignment: .leading, spacing: 8.0) {
                    DetailRow("PERFECT GREAT", value: score.perfectGreatCount, style: scoreStyle())
                    DetailRow("GREAT", value: score.greatCount, style: scoreStyle())
                    DetailRow("MISS", value: score.missCount, style: scoreStyle())
                }
            } else {
                if score.clearType != "NO PLAY" {
                    DetailRow("CLEAR TYPE", value: score.clearType, style: clearTypeStyle())
                }
            }
            OpenYouTubeButton(songTitle: songTitle, level: score.level.code())
            if score.level != .beginner {
                Menu {
                    NavigationLink {
                        TextageViewer(songTitle: songTitle, level: score.level, playSide: .side1P)
                    } label: {
                        Text(verbatim: "1P")
                    }
                    NavigationLink {
                        TextageViewer(songTitle: songTitle, level: score.level, playSide: .side2P)
                    } label: {
                        Text(verbatim: "2P")
                    }
                } label: {
                    ListRow(image: "ListIcon.Textage", title: "Scores.Viewer.OpenTextage", includeSpacer: true)
                }
            }
        } header: {
            IIDXLevelLabel(orientation: .horizontal, levelType: score.level, score: score)
        }
    }

    func clearTypeStyle() -> any ShapeStyle {
        switch score.clearType {
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
