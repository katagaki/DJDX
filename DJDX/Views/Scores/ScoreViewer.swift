//
//  ScoreViewer.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import SwiftData
import SwiftUI

struct ScoreViewer: View {

    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @AppStorage(wrappedValue: false, "ScoresView.BeginnerLevelHidden") var isBeginnerLevelHidden: Bool
    @AppStorage(wrappedValue: IIDXVersion.sparkleShower, "Global.IIDX.Version") var iidxVersion: IIDXVersion

    var songRecord: IIDXSongRecord
    var noteCount: (IIDXSongRecord, IIDXLevel) -> Int?

    var body: some View {
        List {
            if !isBeginnerLevelHidden, songRecord.beginnerScore.difficulty != 0 {
                ScoreSection(songTitle: songRecord.title, score: songRecord.beginnerScore,
                             noteCount: noteCount(songRecord, .beginner),
                             playType: .single) // Only SP has Beginner level
            }
            if songRecord.normalScore.difficulty != 0 {
                ScoreSection(songTitle: songRecord.title, score: songRecord.normalScore,
                             noteCount: noteCount(songRecord, .normal),
                             playType: songRecord.playType)
            }
            if songRecord.hyperScore.difficulty != 0 {
                ScoreSection(songTitle: songRecord.title, score: songRecord.hyperScore,
                             noteCount: noteCount(songRecord, .hyper),
                             playType: songRecord.playType)
            }
            if songRecord.anotherScore.difficulty != 0 {
                ScoreSection(songTitle: songRecord.title, score: songRecord.anotherScore,
                             noteCount: noteCount(songRecord, .another),
                             playType: songRecord.playType)
            }
            if songRecord.leggendariaScore.difficulty != 0 {
                ScoreSection(songTitle: songRecord.title, score: songRecord.leggendariaScore,
                             noteCount: noteCount(songRecord, .leggendaria),
                             playType: songRecord.playType)
            }
        }
        .listSectionSpacing(.compact)
        .navigationTitle("ViewTitle.Scores.Song")
        .navigationBarTitleDisplayMode(.inline)
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
                                    songRecord.version != iidxVersion.marketingName ?
                                        LinearGradient(stops: [
                                            .init(color: .white,
                                                  location: 0.0),
                                            .init(color: .gray,
                                                  location: 1.0)
                                        ], startPoint: .top, endPoint: .bottom)
                                    :
                                        LinearGradient(stops: [
                                            .init(color: Color(red: 234 / 255, green: 254 / 255, blue: 1.0),
                                                  location: 0.0),
                                            .init(color: Color(red: 116 / 255, green: 243 / 255, blue: 248 / 255),
                                                  location: 1.0)
                                        ], startPoint: .top, endPoint: .bottom)
                                )
                                .strokeText(
                                    color: songRecord.version != iidxVersion.marketingName ?
                                        Color(red: 77 / 255, green: 77 / 255, blue: 77 / 255)
                                    :
                                        Color(red: 35 / 255, green: 59 / 255, blue: 158 / 255),
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
                }
                .padding([.bottom], 8.0)
                .padding([.leading, .trailing], 20.0)
            }
        }
        .conditionalBottomTabBarAccessory()
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
