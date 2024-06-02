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
    @Environment(\.openURL) var openURL

    var songTitle: String
    var score: IIDXLevelScore
    var noteCount: Int?

    var body: some View {
        Section {
            if score.djLevelEnum() != .none {
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
            if score.djLevelEnum() != .none {
                VStack(alignment: .leading, spacing: 8.0) {
                    ClearTypeDetailRow("CLEAR TYPE", value: score.clearType, style: clearTypeStyle())
                    DetailRow("SCORE", value: score.score, style: scoreStyle())
                    DetailRow("MISS COUNT", value: score.missCount, style: scoreStyle())
                }
                VStack(alignment: .leading, spacing: 8.0) {
                    NoteTypeDetailRow("PERFECT GREAT", value: score.perfectGreatCount, style: Color.cyan)
                    NoteTypeDetailRow("GREAT", value: score.greatCount, style: Color.yellow)
                    NoteTypeDetailRow("MISS", value: score.missCount, style: Color.red)
                }
            } else {
                if score.clearType != "NO PLAY" {
                    ClearTypeDetailRow("CLEAR TYPE", value: score.clearType, style: clearTypeStyle())
                }
            }
        } header: {
            HStack(spacing: 16.0) {
                IIDXLevelLabel(orientation: .horizontal, levelType: score.level, score: score)
                Spacer()
                Menu {
                    Button("Scores.Viewer.OpenYouTube", image: .listIconYouTube) {
                        let searchQuery: String = "IIDX SP\(score.level.code()) \(songTitle)"
                            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
                        openURL(URL(string: "https://youtube.com/results?search_query=\(searchQuery)")!)
                    }
                    if score.level != .beginner {
                        Section {
                            NavigationLink(value: ViewPath.textageViewer(songTitle: songTitle,
                                                                         level: score.level,
                                                                         playSide: .side1P)) {
                                Label("Scores.Viewer.OpenTextage.1P", image: .listIconTextage)
                            }
                            NavigationLink(value: ViewPath.textageViewer(songTitle: songTitle,
                                                                         level: score.level,
                                                                         playSide: .side2P)) {
                                Label("Scores.Viewer.OpenTextage.2P", image: .listIconTextageFlipped)
                            }
                        } header: {
                            Text("Scores.Viewer.OpenTextage")
                        }
                    }
                } label: {
                    Text("Scores.Viewer.OpenChart")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.text)
                        .padding([.top, .bottom], 4.0)
                        .padding([.leading, .trailing], 12.0)
                        .background(.accent)
                        .clipShape(.capsule(style: .continuous))
                }
                .textCase(.none)
            }
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
                                                              (colorScheme == .dark ? .white : .mint)]),
                                  startPoint: .top,
                                  endPoint: .bottom)
        case "CLEAR":
            return LinearGradient(gradient: Gradient(colors: [(colorScheme == .dark ? .white : .blue),
                                                              .cyan,
                                                              (colorScheme == .dark ? .white : .blue)]),
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
