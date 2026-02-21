//
//  ChartsView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/01.
//

import Komponents
import SwiftSoup
import SwiftUI

struct MoreBemaniWikiCharts: View {

    @Environment(ProgressAlertManager.self) var progressAlertManager
    @EnvironmentObject var navigationManager: NavigationManager

    @AppStorage(wrappedValue: false, "ScoresView.BeginnerLevelHidden") var isBeginnerLevelHidden: Bool
    @AppStorage(wrappedValue: IIDXVersion.sparkleShower, "Global.IIDX.Version") var iidxVersion: IIDXVersion

    @State var allSongs: [IIDXSong] = []

    @State var isReloadCompleted: Bool = false
    @State var dataImported: Int = 0
    @State var dataTotal: Int = 2

    let fetcher = DataFetcher()
    let importer = DataImporter()

    var body: some View {
        List {
            Section {
                Button("More.ExternalData.UpdateData") {
                    progressAlertManager.show(title: "Alert.ExternalData.Downloading.Title",
                                              message: "Alert.ExternalData.Downloading.Text")
                    Task {
                        await reloadData()
                        isReloadCompleted = true
                    }
                }
            }
            Section {
                ForEach(allSongs) { song in
                    NavigationLink(song.title) {
                        List {
                            Section {
                                VStack(alignment: .leading, spacing: 8.0) {
                                    DetailRow("TIME", value: song.time, style: Color.accentColor)
                                    DetailRow("MOVIE", value: song.movie, style: Color.accentColor)
                                    DetailRow("LAYER", value: song.layer, style: Color.accentColor)
                                }
                            }
                            if let noteCount = song.spNoteCount {
                                Section {
                                    VStack(alignment: .leading, spacing: 8.0) {
                                        if !isBeginnerLevelHidden {
                                            LevelDetailRow(level: .beginner, value: noteCount.beginnerNoteCount)
                                        }
                                        LevelDetailRow(level: .normal, value: noteCount.normalNoteCount)
                                        LevelDetailRow(level: .hyper, value: noteCount.hyperNoteCount)
                                        LevelDetailRow(level: .another, value: noteCount.anotherNoteCount)
                                        LevelDetailRow(level: .leggendaria, value: noteCount.leggendariaNoteCount)
                                    }
                                } header: {
                                    ListSectionHeader(text: "SP")
                                        .font(.body)
                                        .fontWidth(.expanded)
                                        .fontWeight(.black)
                                }
                            }
                            if let noteCount = song.dpNoteCount {
                                Section {
                                    VStack(alignment: .leading, spacing: 8.0) {
                                        LevelDetailRow(level: .normal, value: noteCount.normalNoteCount)
                                        LevelDetailRow(level: .hyper, value: noteCount.hyperNoteCount)
                                        LevelDetailRow(level: .another, value: noteCount.anotherNoteCount)
                                        LevelDetailRow(level: .leggendaria, value: noteCount.leggendariaNoteCount)
                                    }
                                } header: {
                                    ListSectionHeader(text: "DP")
                                        .font(.body)
                                        .fontWidth(.expanded)
                                        .fontWeight(.black)
                                }
                            }
                        }
                        .navigationTitle(song.title)
                        .navigationBarTitleDisplayMode(.inline)
                    }
                }
            } header: {
                ListSectionHeader(text: "More.ExternalData.Charts")
                    .font(.body)
            }
        }
        .navigationTitle("ViewTitle.More.BemaniWiki2nd")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: dataImported, { _, _ in
            Task {
                await MainActor.run {
                    progressAlertManager.updateProgress(Int(Float(dataImported) / Float(dataTotal) * 100.0))
                }
            }
        })
        .task {
            allSongs = await fetcher.fetchAllSongs()
        }
        .alert(
            "Alert.ExternalData.Completed.Title",
            isPresented: $isReloadCompleted,
            actions: {
                Button("Shared.OK", role: .cancel) {
                    isReloadCompleted = false
                }
            },
            message: {
                Text("Alert.ExternalData.Completed.Text.\(allSongs.count)")
            }
        )
    }

    func reloadData() async {
        await importer.deleteAllSongs()
        var iidxSongs: [IIDXSong] = []
        iidxSongs.append(contentsOf: await reloadBemaniWikiDataForLatestVersion())
        dataImported += 1
        iidxSongs.append(contentsOf: await reloadBemaniWikiDataForExistingVersions())
        dataImported += 1
        await importer.insertSongs(iidxSongs)
        allSongs = await fetcher.fetchAllSongs()
        await MainActor.run {
            progressAlertManager.hide()
            withAnimation(.snappy.speed(2.0)) {
                dataImported = 0
            }
        }
    }

    func reloadBemaniWikiDataForLatestVersion() async -> [IIDXSong] {
        do {
            var iidxSongsFromWiki: [IIDXSong] = []
            let (data, _) = try await URLSession.shared.data(from: iidxVersion.bemaniWikiLatestVersionPageURL())
            if let htmlString = String(bytes: data, encoding: .japaneseEUC),
               let htmlDocument = try? SwiftSoup.parse(htmlString),
               let htmlDocumentBody = htmlDocument.body(),
               let documentContents = try? htmlDocumentBody.select("#contents").first(),
               let documentBody = try? documentContents.select("#body").first() {
                // Get index of first h3 containing text '総ノーツ数'
                let indexOfHeader = documentBody.children().firstIndex { element in
                    // 32 and below: h3
                    // 33 and above: h4
                    (element.tag().getName() == "h3" || element.tag().getName() == "h4") &&
                    (try? element.text().contains("総ノーツ数")) ?? false
                }
                if let indexOfHeader {
                    // Get every element after the header
                    let documentAfterHeader = Elements(Array(documentBody.children()[
                        indexOfHeader..<documentBody.children().count
                    ]))
                    // Find the table in the document
                    if let tables = try? documentAfterHeader.select("div.ie5") {
                        for table in tables {
                            debugPrint(table)
                            if let tableRows = try? table.select("tr") {
                                // Get all the rows in the document, and only take the rows that have 13 columns
                                for tableRow in tableRows {
                                    if let tableRowColumns = try? tableRow.select("td"),
                                       tableRowColumns.count == 13 {
                                        let tableColumnData = tableRowColumns.compactMap({ try? $0.text()})
                                        if tableColumnData.count == 13 {
                                            let iidxSong = IIDXSong(tableColumnData)
                                            iidxSongsFromWiki.append(iidxSong)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            return iidxSongsFromWiki
        } catch {
            debugPrint(error.localizedDescription)
            return []
        }
    }

    func reloadBemaniWikiDataForExistingVersions() async -> [IIDXSong] {
        do {
            var iidxSongsFromWiki: [IIDXSong] = []
            let (data, _) = try await URLSession.shared.data(from: iidxVersion.bemaniWikiExistingVersionsPageURL())
            if let htmlString = String(bytes: data, encoding: .japaneseEUC),
               let htmlDocument = try? SwiftSoup.parse(htmlString),
               let htmlDocumentBody = htmlDocument.body(),
               let documentContents = try? htmlDocumentBody.select("#contents").first(),
               let documentBody = try? documentContents.select("#body").first(),
               let tables = try? documentBody.select("div.ie5") {
                for table in tables {
                    if let tableRows = try? table.select("tr") {
                        // Get all the rows in the document, and only take the rows that have 13 columns
                        for tableRow in tableRows {
                            if let tableRowColumns = try? tableRow.select("td"),
                               tableRowColumns.count == 13 {
                                let tableColumnData = tableRowColumns.compactMap({ try? $0.text()})
                                if tableColumnData.count == 13 {
                                    let iidxSong = IIDXSong(tableColumnData)
                                    iidxSongsFromWiki.append(iidxSong)
                                }
                            }
                        }
                    }
                }
            }
            return iidxSongsFromWiki
        } catch {
            debugPrint(error.localizedDescription)
            return []
        }
    }
}
