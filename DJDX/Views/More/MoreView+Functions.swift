//
//  MoreView+Functions.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/01.
//

import Foundation
import SwiftSoup
import WebKit

extension MoreView {
    func updateProgress() async {
        await MainActor.run {
            let imported = Float(latestVersionDataImported) + Float(existingVersionDataImported)
            let total = Float(latestVersionDataCount) + Float(existingVersionDataCount)
            progressAlertManager.updateProgress(Int(imported / total * 100.0))
        }
    }

    func reloadBemaniWikiDataForLatestVersion() async -> [IIDXSong] {
        do {
            var iidxSongsFromWiki: [IIDXSong] = []
            let (data, _) = try await URLSession.shared.data(from: bemaniWikiLatestVersionPageURL)
            if let htmlString = String(bytes: data, encoding: .japaneseEUC),
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
                        latestVersionDataCount = tableRows.count
                        for tableRow in tableRows {
                            if let tableRowColumns = try? tableRow.select("td"),
                               tableRowColumns.count == 13 {
                                let tableColumnData = tableRowColumns.compactMap({ try? $0.text()})
                                if tableColumnData.count == 13 {
                                    let iidxSong = IIDXSong(tableColumnData)
                                    iidxSongsFromWiki.append(iidxSong)
                                }
                            }
                            latestVersionDataImported += 1
                            await updateProgress()
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
            let (data, _) = try await URLSession.shared.data(from: bemaniWikiExistingVersionsPageURL)
            if let htmlString = String(bytes: data, encoding: .japaneseEUC),
               let htmlDocument = try? SwiftSoup.parse(htmlString),
               let htmlDocumentBody = htmlDocument.body(),
               let documentContents = try? htmlDocumentBody.select("#contents").first(),
               let documentBody = try? documentContents.select("#body").first() {
                // Find the table in the document
                if let table = try? documentBody.select("div.ie5")[1],
                   let tableRows = try? table.select("tr") {
                    // Get all the rows in the document, and only take the rows that have 13 columns
                    existingVersionDataCount = tableRows.count
                    for tableRow in tableRows {
                        if let tableRowColumns = try? tableRow.select("td"),
                           tableRowColumns.count == 13 {
                            let tableColumnData = tableRowColumns.compactMap({ try? $0.text()})
                            if tableColumnData.count == 13 {
                                let iidxSong = IIDXSong(tableColumnData)
                                iidxSongsFromWiki.append(iidxSong)
                            }
                        }
                        existingVersionDataImported += 1
                        await updateProgress()
                    }
                }
            }
            return iidxSongsFromWiki
        } catch {
            debugPrint(error.localizedDescription)
            return []
        }
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
