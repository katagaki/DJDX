//
//  MoreView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import Komponents
import SwiftUI

let bemaniWikiLatestVersionPageURL = URL(string: """
https://bemaniwiki.com/?beatmania+IIDX+31+EPOLIS/%BF%B7%B6%CA%A5%EA%A5%B9%A5%C8
""")!
let bemaniWikiExistingVersionsPageURL = URL(string: """
https://bemaniwiki.com/?beatmania+IIDX+31+EPOLIS/%B5%EC%B6%CA%C1%ED%A5%CE%A1%BC%A5%C4%BF%F4%A5%EA%A5%B9%A5%C8
""")!

struct MoreView: View {

    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var navigationManager: NavigationManager

    @AppStorage(wrappedValue: false, "ScoresView.LevelsShownSeparately") var isLevelsShownSeparately: Bool
    @AppStorage(wrappedValue: false, "ScoresView.ArtistVisible") var isArtistVisible: Bool
    @AppStorage(wrappedValue: true, "ScoresView.LevelVisible") var isLevelVisible: Bool
    @AppStorage(wrappedValue: false, "ScorewView.GenreVisible") var isGenreVisible: Bool
    @AppStorage(wrappedValue: true, "ScorewView.ScoreVisible") var isScoreVisible: Bool
    @AppStorage(wrappedValue: false, "ScorewView.LastPlayDateVisible") var isLastPlayDateVisible: Bool

    @State var isDownloadingExternalData: Bool = false
    @State var isConfirmingWebDataDelete: Bool = false
    @State var isConfirmingScoreDataDelete: Bool = false

    @State var currentProgress: Int = 0
    @State var latestVersionDataCount: Int = 1
    @State var latestVersionDataImported: Int = 0
    @State var existingVersionDataCount: Int = 1
    @State var existingVersionDataImported: Int = 0

    var body: some View {
        NavigationStack(path: $navigationManager[.more]) {
            MoreList(repoName: "katagaki/DJDX", viewPath: ViewPath.moreAttributions) {
                Section {
                    Button("More.ExternalData.DownloadWikiData") {
                        Task {
                            withAnimation(.snappy.speed(2.0)) {
                                isDownloadingExternalData = true
                            }
                            try? modelContext.delete(model: IIDXSong.self)
                            await withTaskGroup(of: Void.self) { group in
                                group.addTask {
                                    await reloadBemaniWikiDataForLatestVersion()
                                }
                                group.addTask {
                                    await reloadBemaniWikiDataForExistingVersions()
                                }
                            }
                            withAnimation(.snappy.speed(2.0)) {
                                isDownloadingExternalData = false
                                currentProgress = 0
                                latestVersionDataCount = 1
                                latestVersionDataImported = 0
                                existingVersionDataCount = 1
                                existingVersionDataImported = 0
                            }
                        }
                    }
                } header: {
                    ListSectionHeader(text: "More.ExternalData.Header")
                        .font(.body)
                }
                Section {
                    Toggle(isOn: $isLevelsShownSeparately) {
                        HStack(spacing: 0.0) {
                            ListRow(image: "ListIcon.ShowLevelsAsSeparateRecords",
                                    title: "More.PlayDataDisplay.ShowLevelsSeparately",
                                    subtitle: "More.PlayDataDisplay.ShowLevelsSeparately.Description",
                                    includeSpacer: true)
                        }
                    }
                    .disabled(true)
                    Toggle(isOn: $isArtistVisible) {
                        ListRow(image: "ListIcon.ShowArtist",
                                title: "More.PlayDataDisplay.ShowArtist",
                                includeSpacer: true)
                    }
                    Toggle(isOn: $isLevelVisible) {
                        ListRow(image: "ListIcon.ShowLevel",
                                title: "More.PlayDataDisplay.ShowLevel",
                                includeSpacer: true)
                    }
                    Toggle(isOn: $isGenreVisible) {
                        ListRow(image: "ListIcon.ShowGenre",
                                title: "More.PlayDataDisplay.ShowGenre",
                                includeSpacer: true)
                    }
                    Toggle(isOn: $isLastPlayDateVisible) {
                        ListRow(image: "ListIcon.ShowPlayDate",
                                title: "More.PlayDataDisplay.ShowLastPlayDate",
                                includeSpacer: true)
                    }
                    Toggle(isOn: $isScoreVisible) {
                        ListRow(image: "ListIcon.ShowScore",
                                title: "More.PlayDataDisplay.ShowScore",
                                includeSpacer: true)
                    }
                } header: {
                    ListSectionHeader(text: "More.PlayDataDisplay.Header")
                        .font(.body)
                }
                Section {
                    Button {
                        isConfirmingWebDataDelete = true
                    } label: {
                        Text("More.ManageData.DeleteWebData")
                            .foregroundStyle(.red)
                    }
                    Button {
                        isConfirmingScoreDataDelete = true
                    } label: {
                        Text("More.ManageData.DeleteScoreData")
                            .foregroundStyle(.red)
                    }
                } header: {
                    ListSectionHeader(text: "More.ManageData.Header")
                        .font(.body)
                }
            }
            .alert(
                "Alert.DeleteData.Web.Title",
                isPresented: $isConfirmingWebDataDelete,
                actions: {
                    Button("Alert.DeleteData.Web.Confirm", role: .destructive) {
                        deleteAllWebData()
                    }
                    Button("Shared.Cancel", role: .cancel) {
                        isConfirmingWebDataDelete = false
                    }
                },
                message: {
                    Text("Alert.DeleteData.Web.Subtitle")
                })
            .alert(
                "Alert.DeleteData.Score.Title",
                isPresented: $isConfirmingScoreDataDelete,
                actions: {
                    Button("Alert.DeleteData.Score.Confirm", role: .destructive) {
                        deleteAllScoreData()
                    }
                    Button("Shared.Cancel", role: .cancel) {
                        isConfirmingScoreDataDelete = false
                    }
                },
                message: {
                    Text("Alert.DeleteData.Score.Subtitle")
                })
            .navigationDestination(for: ViewPath.self, destination: { viewPath in
                switch viewPath {
                case .moreAttributions:
                    LicensesView(licenses: [
                        License(libraryName: "CSwiftV", text:
"""
Copyright (c) 2015, Daniel Haight


All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.
    * Neither the name of CSwiftV nor the names of its contributors
      may be used to endorse or promote products derived from this software
      without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
""")])
                default: Color.clear
                }
            })
        }
        .overlay {
            if isDownloadingExternalData {
                ProgressAlert(
                    title: "Alert.ExternalData.Downloading.Title",
                    message: "Alert.ExternalData.Downloading.Text",
                    percentage: $currentProgress
                )
            }
        }
    }
}
