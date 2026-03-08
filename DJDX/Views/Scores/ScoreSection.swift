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
    @EnvironmentObject var navigationManager: NavigationManager

    var songTitle: String
    var score: IIDXLevelScore
    var noteCount: Int?
    var playType: IIDXPlayType
    var chartRadarData: ChartRadarData?

    @State private var isShowingRadarValues: Bool = false

    var body: some View {
        Section {
            if score.djLevelEnum() != .none {
                HStack {
                    Group {
                        switch colorScheme {
                        case .light:
                            Text(score.djLevel)
                                .foregroundStyle(IIDXDJLevel.style(for: score.djLevel, colorScheme: colorScheme))
                                .conditionalShadow(.blue.opacity(0.2), radius: 3.0)
                        case .dark:
                            Text(score.djLevel)
                                .foregroundStyle(IIDXDJLevel.style(for: score.djLevel, colorScheme: colorScheme))
                                .drawingGroup()
                                .shadow(color: .cyan, radius: 5.0)
                        @unknown default:
                            Text(score.djLevel)
                        }
                        Spacer()
                        if let noteCount {
                            Text(Float(score.score) / Float(noteCount * 2),
                                 format: .percent.precision(.fractionLength(1)))
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
                HStack(spacing: 0.0) {
                    NoteTypeDetailRow("P-GREAT", value: score.perfectGreatCount, style: Color.cyan)
                    NoteTypeDetailRow("GREAT", value: score.greatCount, style: Color.yellow)
                    NoteTypeDetailRow("MISS", value: score.missCount, style: Color.red)
                }
            } else {
                if score.clearType != "NO PLAY" {
                    ClearTypeDetailRow("CLEAR TYPE", value: score.clearType, style: clearTypeStyle())
                }
            }
            if let chartRadarData {
                Button {
                    isShowingRadarValues.toggle()
                } label: {
                    Group {
                        if isShowingRadarValues {
                            VStack(spacing: 4.0) {
                                ForEach(chartRadarData.radarData.displayPoints(), id: \.label) { point in
                                    HStack {
                                        Text(verbatim: point.label)
                                            .font(.system(size: 12, weight: .bold))
                                            .fontWidth(.expanded)
                                            .foregroundStyle(point.color)
                                        Spacer()
                                        Text(verbatim: String(format: "%.2f", point.value))
                                            .font(.system(size: 12, weight: .semibold).monospacedDigit())
                                            .foregroundStyle(.primary)
                                    }
                                }
                            }
                            .padding(.vertical, 4.0)
                        } else {
                            RadarChartView(chartRadarData.radarData)
                                .frame(height: 200.0)
                                .padding(.vertical, 4.0)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            chartActions()
        } header: {
            HStack(spacing: 16.0) {
                IIDXLevelLabel(orientation: .horizontal, levelType: score.level, score: score)
                Spacer()
                if score.djLevelEnum() != .none {
                    NavigationLink(value: ViewPath.scoreHistory(songTitle: songTitle,
                                                                level: score.level,
                                                                noteCount: noteCount)) {
                        Image(systemName: "clock.arrow.circlepath")
                    }.accessibilityLabel("Scores.Viewer.ShowHistory")
                }
            }
        }
    }

    @ViewBuilder
    func chartActions() -> some View {
        HStack(spacing: 0.0) {
            Button {
                openYouTube()
            } label: {
                chartActionLabel(image: Image(.listIconYouTube), label: "YouTube")
            }
            .buttonStyle(.plain)
            if score.level != .beginner {
                switch playType {
                case .single:
                    Divider()
                    Button {
                        navigationManager.push(.textageViewer(songTitle: songTitle,
                                                              level: score.level,
                                                              playSide: .side1P,
                                                              playType: playType), for: .scores)
                    } label: {
                        chartActionLabel(image: Image(.listIconTextage),
                                         label: "Scores.Viewer.OpenTextage.1P")
                    }
                    .buttonStyle(.plain)
                    Divider()
                    Button {
                        navigationManager.push(.textageViewer(songTitle: songTitle,
                                                              level: score.level,
                                                              playSide: .side2P,
                                                              playType: playType), for: .scores)
                    } label: {
                        chartActionLabel(image: Image(.listIconTextageFlipped),
                                         label: "Scores.Viewer.OpenTextage.2P")
                    }
                    .buttonStyle(.plain)
                case .double:
                    Divider()
                    Button {
                        navigationManager.push(.textageViewer(songTitle: songTitle,
                                                              level: score.level,
                                                              playSide: .notApplicable,
                                                              playType: playType), for: .scores)
                    } label: {
                        chartActionLabel(image: Image(.listIconTextage),
                                         label: "Scores.Viewer.OpenTextage.DP")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func chartActionLabel(image: Image, label: LocalizedStringKey) -> some View {
        VStack(spacing: 8.0) {
            image
                .resizable()
                .scaledToFit()
                .frame(width: 26.0, height: 26.0)
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
    }

    func clearTypeStyle() -> any ShapeStyle {
        IIDXClearType.style(for: score.clearType, colorScheme: colorScheme)
    }

    func openYouTube() {
        switch playType {
        case .single:
            let searchQuery: String = "IIDX SP\(score.level.code()) \(songTitle)"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            openURL(URL(string: "https://youtube.com/results?search_query=\(searchQuery)")!)
        case .double:
            let searchQuery: String = "IIDX DP\(score.level.code()) \(songTitle)"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            openURL(URL(string: "https://youtube.com/results?search_query=\(searchQuery)")!)
        }
    }

    func scoreStyle() -> any ShapeStyle {
        return LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom)
    }
}
