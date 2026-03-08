//
//  ScoreViewer.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import SwiftUI

// swiftlint:disable:next type_body_length
struct ScoreViewer: View {

    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @AppStorage(wrappedValue: false, "ScoresView.BeginnerLevelHidden") var isBeginnerLevelHidden: Bool
    @AppStorage(wrappedValue: IIDXVersion.sparkleShower, "Global.IIDX.Version") var iidxVersion: IIDXVersion

    var songRecord: IIDXSongRecord
    var noteCount: (IIDXSongRecord, IIDXLevel) -> Int?
    var initialLevel: IIDXLevel

    @State private var selectedLevel: IIDXLevel = .all
    @State private var radarDataByLevel: [String: ChartRadarData] = [:]

    private let radarFetcher = DataFetcher()

    var availableLevels: [IIDXLevel] {
        var levels: [IIDXLevel] = []
        if !isBeginnerLevelHidden, songRecord.beginnerScore.difficulty != 0 {
            levels.append(.beginner)
        }
        if songRecord.normalScore.difficulty != 0 { levels.append(.normal) }
        if songRecord.hyperScore.difficulty != 0 { levels.append(.hyper) }
        if songRecord.anotherScore.difficulty != 0 { levels.append(.another) }
        if songRecord.leggendariaScore.difficulty != 0 { levels.append(.leggendaria) }
        return levels
    }

    var body: some View {
        List {
            if selectedLevel == .all || selectedLevel == .beginner {
                if !isBeginnerLevelHidden, songRecord.beginnerScore.difficulty != 0 {
                    ScoreSection(songTitle: songRecord.title, score: songRecord.beginnerScore,
                                 noteCount: noteCount(songRecord, .beginner),
                                 playType: .single,
                                 chartRadarData: radarDataByLevel["SP-0"])
                }
            }
            if selectedLevel == .all || selectedLevel == .normal {
                if songRecord.normalScore.difficulty != 0 {
                    ScoreSection(songTitle: songRecord.title, score: songRecord.normalScore,
                                 noteCount: noteCount(songRecord, .normal),
                                 playType: songRecord.playType,
                                 chartRadarData: radarDataByLevel[radarKey(songRecord.playType, 1)])
                }
            }
            if selectedLevel == .all || selectedLevel == .hyper {
                if songRecord.hyperScore.difficulty != 0 {
                    ScoreSection(songTitle: songRecord.title, score: songRecord.hyperScore,
                                 noteCount: noteCount(songRecord, .hyper),
                                 playType: songRecord.playType,
                                 chartRadarData: radarDataByLevel[radarKey(songRecord.playType, 2)])
                }
            }
            if selectedLevel == .all || selectedLevel == .another {
                if songRecord.anotherScore.difficulty != 0 {
                    ScoreSection(songTitle: songRecord.title, score: songRecord.anotherScore,
                                 noteCount: noteCount(songRecord, .another),
                                 playType: songRecord.playType,
                                 chartRadarData: radarDataByLevel[radarKey(songRecord.playType, 3)])
                }
            }
            if selectedLevel == .all || selectedLevel == .leggendaria {
                if songRecord.leggendariaScore.difficulty != 0 {
                    ScoreSection(songTitle: songRecord.title, score: songRecord.leggendariaScore,
                                 noteCount: noteCount(songRecord, .leggendaria),
                                 playType: songRecord.playType,
                                 chartRadarData: radarDataByLevel[radarKey(songRecord.playType, 4)])
                }
            }
        }
        .navigator("ViewTitle.Scores.Song", group: true, inline: true)
        .scrollContentBackground(.hidden)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Spacer()
            }
            versionNumberToolbarItem()
        }
        .safeAreaInset(edge: .top, spacing: 0.0) {
            TabBarAccessory(placement: .top) {
                VStack(alignment: .center, spacing: 8.0) {
                    VStack(alignment: .center, spacing: 4.0) {
                        Group {
                            Text(songRecord.genre)
                                .font(.subheadline)
                                .fontWeight(.heavy)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white)
                                .strokeText(color: .black.opacity(0.7), width: 0.5)
                            Text(songRecord.title)
                                .font(.title)
                                .fontWeight(.heavy)
                                .fontWidth(.compressed)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(
                                    iidxVersion.songTitleTextColor(for: songRecord.version)
                                )
                                .strokeText(
                                    color: iidxVersion.songTitleStrokeColor(for: songRecord.version),
                                    width: 0.5
                                )
                                .textSelection(.enabled)
                                .padding(.bottom, 2.0)
                            Text(songRecord.artist)
                                .font(.subheadline)
                                .fontWeight(.heavy)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white)
                                .strokeText(color: .black.opacity(0.7), width: 0.5)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    }
                    .frame(maxWidth: .infinity)
                    Divider()
                    HStack {
                        Text("""
Scores.Viewer.LastPlayDate.\(songRecord.lastPlayDate.formatted(date: .long, time: .shortened))
""")
                        .foregroundStyle(.tertiary)
                    }
                    .font(.caption2)
                    difficultySwitcher()
                }
                .padding([.bottom], 8.0)
                .padding([.leading, .trailing], 20.0)
            }
        }
        .conditionalBottomTabBarAccessory()
        .task {
            await loadRadarData()
        }
        .onAppear {
            if initialLevel != .all, availableLevels.contains(initialLevel) {
                selectedLevel = initialLevel
            }
        }
    }

    @ViewBuilder
    private func difficultySwitcher() -> some View {
        HStack(spacing: 6.0) {
            ForEach(availableLevels, id: \.self) { level in
                difficultyChip(level: level,
                               label: String(difficultyNumber(for: level)),
                               color: difficultyColor(for: level))
            }
        }
        .padding(.top, 4.0)
    }

    @ViewBuilder
    private func difficultyChip(level: IIDXLevel, label: String, color: Color) -> some View {
        Button {
            withAnimation(.snappy.speed(2.0)) {
                if selectedLevel == level {
                    selectedLevel = .all
                } else {
                    selectedLevel = level
                }
            }
        } label: {
            Text(verbatim: label)
                .font(.title3)
                .fontWeight(.heavy)
                .fontWidth(.expanded)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8.0)
                .background(selectedLevel == level ? color : color.opacity(0.1))
                .foregroundStyle(selectedLevel == level ? .white : .secondary)
                .clipShape(.capsule)
                .overlay {
                    if selectedLevel != level {
                        Capsule(style: .continuous)
                            .stroke(.secondary.opacity(0.3), lineWidth: 1.0)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func difficultyNumber(for level: IIDXLevel) -> Int {
        switch level {
        case .beginner: return songRecord.beginnerScore.difficulty
        case .normal: return songRecord.normalScore.difficulty
        case .hyper: return songRecord.hyperScore.difficulty
        case .another: return songRecord.anotherScore.difficulty
        case .leggendaria: return songRecord.leggendariaScore.difficulty
        default: return 0
        }
    }

    private func difficultyColor(for level: IIDXLevel) -> Color {
        switch level {
        case .beginner: return .green
        case .normal: return .blue
        case .hyper: return .orange
        case .another: return .red
        case .leggendaria: return .purple
        default: return .accent
        }
    }

    private func radarKey(_ playType: IIDXPlayType, _ difficulty: Int) -> String {
        let pt = playType == .single ? "SP" : "DP"
        return "\(pt)-\(difficulty)"
    }

    private func loadRadarData() async {
        let difficulties = [
            (IIDXPlayType.single, 0, songRecord.beginnerScore.difficulty),
            (songRecord.playType, 1, songRecord.normalScore.difficulty),
            (songRecord.playType, 2, songRecord.hyperScore.difficulty),
            (songRecord.playType, 3, songRecord.anotherScore.difficulty),
            (songRecord.playType, 4, songRecord.leggendariaScore.difficulty)
        ]

        var results: [String: ChartRadarData] = [:]
        for (playType, bm2dxDifficulty, chartDifficulty) in difficulties {
            guard chartDifficulty != 0 else { continue }
            if let data = await radarFetcher.fetchChartRadarData(
                title: songRecord.title,
                playType: playType,
                difficulty: bm2dxDifficulty
            ) {
                results[radarKey(playType, bm2dxDifficulty)] = data
            }
        }

        await MainActor.run {
            radarDataByLevel = results
        }
    }

    @ToolbarContentBuilder
    func versionNumberToolbarItem() -> some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarTrailing) {
                versionNumberToolbarItemContent()
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                versionNumberToolbarItemContent()
            }
        }
    }

    @ViewBuilder
    func versionNumberToolbarItemContent() -> some View {
        Group {
            if let iidxVersion = IIDXVersion.marketingNames[songRecord.version] {
                switch colorScheme {
                case .dark:
                    Text(songRecord.version)
                        .foregroundStyle(Color(uiColor: iidxVersion.darkModeColor))
                default:
                    Text(songRecord.version)
                        .foregroundStyle(Color(uiColor: iidxVersion.lightModeColor))
                }
            } else {
                Text(songRecord.version)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
        .fontWeight(.heavy)
        .italic()
    }
}
