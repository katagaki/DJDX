//
//  MoreView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import Komponents
import SwiftSoup
import SwiftUI
import WebKit

let latestVersionPageURL = URL(string: """
https://bemaniwiki.com/?beatmania+IIDX+31+EPOLIS/%BF%B7%B6%CA%A5%EA%A5%B9%A5%C8
""")!
let existingVersionsPageURL = URL(string: """
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

    @State var isConfirmingWebDataDelete: Bool = false
    @State var isConfirmingScoreDataDelete: Bool = false

    var body: some View {
        NavigationStack(path: $navigationManager[.more]) {
            MoreList(repoName: "katagaki/DJDX", viewPath: ViewPath.moreAttributions) {
                Section {
                    Button("More.ExternalData.DownloadWikiData") {
                        try? modelContext.delete(model: IIDXSong.self)
                        reloadBemaniWikiDataForLatestVersion()
                        reloadBemaniWikiDataForExistingVersions()
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
    }

    func reloadBemaniWikiDataForLatestVersion() {
        URLSession.shared.dataTask(with: URLRequest(url: latestVersionPageURL)) { data, _, error in
            if let data,
               let htmlString = String(bytes: data, encoding: .japaneseEUC),
               let htmlDocument = try? SwiftSoup.parse(htmlString),
               let htmlDocumentBody = htmlDocument.body(),
               let documentContents = try? htmlDocumentBody.select("#contents").first(),
               let documentBody = try? documentContents.select("#body").first() {
                // Get index of first h3 containing text '総ノーツ数'
                let indexOfHeader = documentBody.children().firstIndex { element in
                    element.tag().getName() == "h3" && (try? element.text().contains("総ノーツ数")) ?? false
                }
                if let indexOfHeader {
                    // Get every element after the header
                    let documentAfterHeader = Elements(Array(documentBody.children()[
                        indexOfHeader..<documentBody.children().count
                    ]))
                    // Find the table in the document
                    if let tablesInDocument = try? documentAfterHeader.select("div.ie5"),
                       let table = tablesInDocument.first(),
                       let tableRows = try? table.select("tr") {
                        // Get all the rows in the document, and only take the rows that have 13 columns
                        for tableRow in tableRows {
                            if let tableRowColumns = try? tableRow.select("td"),
                               tableRowColumns.count == 13 {
                                let tableColumnData = tableRowColumns.compactMap({ try? $0.text()})
                                if tableColumnData.count == 13 {
                                    let iidxSong = IIDXSong(tableColumnData)
                                    modelContext.insert(iidxSong)
                                }
                            }
                        }
                    }
                }
            } else if let error {
                debugPrint("Could not refresh data from BEMANIWiki 2nd: \(error.localizedDescription)")
            }
        }.resume()
    }

    func reloadBemaniWikiDataForExistingVersions() {
        URLSession.shared.dataTask(with: URLRequest(url: existingVersionsPageURL)) { data, _, error in
            if let data,
               let htmlString = String(bytes: data, encoding: .japaneseEUC),
               let htmlDocument = try? SwiftSoup.parse(htmlString),
               let htmlDocumentBody = htmlDocument.body(),
               let documentContents = try? htmlDocumentBody.select("#contents").first(),
               let documentBody = try? documentContents.select("#body").first() {
                // Find the table in the document
                if let table = try? documentBody.select("div.ie5")[1],
                   let tableRows = try? table.select("tr") {
                    // Get all the rows in the document, and only take the rows that have 13 columns
                    for tableRow in tableRows {
                        if let tableRowColumns = try? tableRow.select("td"),
                           tableRowColumns.count == 13 {
                            let tableColumnData = tableRowColumns.compactMap({ try? $0.text()})
                            if tableColumnData.count == 13 {
                                let iidxSong = IIDXSong(tableColumnData)
                                modelContext.insert(iidxSong)
                            }
                        }
                    }
                }
            } else if let error {
                debugPrint("Could not refresh data from BEMANIWiki 2nd: \(error.localizedDescription)")
            }
        }.resume()
    }

    func deleteAllWebData() {
        WKWebsiteDataStore.default()
            .fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
                records.forEach { record in
                    WKWebsiteDataStore.default().removeData(ofTypes: record.dataTypes,
                                                            for: [record],
                                                            completionHandler: {})
                }
            }
    }

    func deleteAllScoreData() {
        try? modelContext.delete(model: ImportGroup.self)
        try? modelContext.delete(model: IIDXSongRecord.self)
    }
}
