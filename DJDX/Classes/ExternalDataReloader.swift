import Foundation
import SwiftSoup

enum ExternalDataSourceID: String, CaseIterable {
    case textage
    case sdvxIn
    case wikiIidx
    case bm2dx
    case wikiDdr
}

@MainActor
struct ExternalDataReloader {

    typealias Progress = (Int, Int) -> Void

    @discardableResult
    static func reload(
        _ id: ExternalDataSourceID,
        iidxVersion: IIDXVersion,
        progress: Progress = { _, _ in }
    ) async -> Int {
        switch id {
        case .textage: await reloadTextage(progress: progress)
        case .sdvxIn: await reloadSDVXIn(progress: progress)
        case .wikiIidx: await reloadWikiIIDX(version: iidxVersion, progress: progress)
        case .bm2dx: await reloadBM2DX(progress: progress)
        case .wikiDdr: await reloadWikiDDR(progress: progress)
        }
    }

    // MARK: - Textage

    private static func reloadTextage(progress: Progress) async -> Int {
        progress(0, 2)
        guard let titleURL = URL(string: "https://textage.cc/score/titletbl.js"),
              let accessURL = URL(string: "https://textage.cc/score/actbl.js") else { return 0 }

        var titleTableText: String?
        var accessTableText: String?

        if let (data, _) = try? await URLSession.shared.data(from: titleURL) {
            titleTableText = data.decodedAsTextageTable()
        }
        progress(1, 2)

        if let (data, _) = try? await URLSession.shared.data(from: accessURL) {
            accessTableText = data.decodedAsTextageTable()
        }
        progress(2, 2)

        guard let titleTableText, let accessTableText else { return 0 }
        let charts = TextageTableParser.charts(titleTableText: titleTableText,
                                               accessTableText: accessTableText)
        await TextageImporter().replaceAllCharts(charts)
        return await IIDXReader().textageChartCount()
    }

    // MARK: - sdvx.in

    private static func reloadSDVXIn(progress: Progress) async -> Int {
        var charts: [SDVXInChart] = []
        let pattern = "SORT([0-9]{5})([NAEMnaem])\\(\\);</script><!--(.*?)-->"
        let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])

        progress(0, 20)
        for level in 1...20 {
            defer { progress(level, 20) }
            let levelSlug = String(format: "%02d", level)
            guard let regex,
                  let url = URL(string: "https://sdvx.in/sort/sort_\(levelSlug).htm"),
                  let (data, _) = try? await URLSession.shared.data(from: url),
                  let html = String(data: data, encoding: .utf8) else { continue }
            let htmlString = html as NSString
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: htmlString.length))
            for match in matches where match.numberOfRanges == 4 {
                let code = htmlString.substring(with: match.range(at: 1))
                let slot = htmlString.substring(with: match.range(at: 2)).lowercased()
                let rawTitle = htmlString.substring(with: match.range(at: 3))
                let title = ((try? SwiftSoup.Entities.unescape(rawTitle)) ?? rawTitle)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { continue }
                charts.append(SDVXInChart(code: code, slot: slot, title: title, level: level))
            }
        }

        await SDVXInImporter().replaceAllCharts(charts)
        return await SDVXReader().sdvxInChartCount()
    }

    // MARK: - BEMANIWiki (beatmania IIDX note counts)

    private static func reloadWikiIIDX(version: IIDXVersion, progress: Progress) async -> Int {
        let importer = IIDXImporter()
        progress(0, 2)
        await importer.deleteAllSongs()
        var iidxSongs: [IIDXSong] = []
        iidxSongs.append(contentsOf: await songsForLatestVersion(version: version))
        progress(1, 2)
        iidxSongs.append(contentsOf: await songsForExistingVersions(version: version))
        progress(2, 2)
        await importer.insertSongs(iidxSongs)
        return await IIDXReader().bemaniWikiSongCount()
    }

    private static func songsForLatestVersion(version: IIDXVersion) async -> [IIDXSong] {
        do {
            var iidxSongsFromWiki: [IIDXSong] = []
            let (data, _) = try await URLSession.shared.data(from: version.bemaniWikiLatestVersionPageURL())
            if let htmlString = String(bytes: data, encoding: .utf8),
               let htmlDocument = try? SwiftSoup.parse(htmlString),
               let htmlDocumentBody = htmlDocument.body(),
               let documentContents = try? htmlDocumentBody.select("#contents").first(),
               let documentBody = try? documentContents.select("#body").first() {
                let indexOfHeader = documentBody.children().firstIndex { element in
                    (element.tag().getName() == "h3" || element.tag().getName() == "h4") &&
                    (try? element.text().contains("総ノーツ数")) ?? false
                }
                if let indexOfHeader {
                    let documentAfterHeader = Elements(Array(documentBody.children()[
                        indexOfHeader..<documentBody.children().count
                    ]))
                    if let tables = try? documentAfterHeader.select("div.ie5") {
                        for table in tables {
                            if let tableRows = try? table.select("tr") {
                                for tableRow in tableRows {
                                    if let tableRowColumns = try? tableRow.select("td"),
                                       tableRowColumns.count == 13 {
                                        let tableColumnData = tableRowColumns.compactMap({ try? $0.text() })
                                        if tableColumnData.count == 13 {
                                            iidxSongsFromWiki.append(IIDXSong(tableColumnData))
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

    private static func songsForExistingVersions(version: IIDXVersion) async -> [IIDXSong] {
        do {
            var iidxSongsFromWiki: [IIDXSong] = []
            let (data, _) = try await URLSession.shared.data(from: version.bemaniWikiExistingVersionsPageURL())
            if let htmlString = String(bytes: data, encoding: .utf8),
               let htmlDocument = try? SwiftSoup.parse(htmlString),
               let htmlDocumentBody = htmlDocument.body(),
               let documentContents = try? htmlDocumentBody.select("#contents").first(),
               let documentBody = try? documentContents.select("#body").first(),
               let tables = try? documentBody.select("div.ie5") {
                for table in tables {
                    if let tableRows = try? table.select("tr") {
                        for tableRow in tableRows {
                            if let tableRowColumns = try? tableRow.select("td"),
                               tableRowColumns.count == 13 {
                                let tableColumnData = tableRowColumns.compactMap({ try? $0.text() })
                                if tableColumnData.count == 13 {
                                    iidxSongsFromWiki.append(IIDXSong(tableColumnData))
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

    // MARK: - bm2dx.com

    private static func reloadBM2DX(progress: Progress) async -> Int {
        let importer = IIDXImporter()
        progress(0, 1)
        await importer.deleteAllNotesRadar()
        var allEntries: [ChartRadarData] = []

        do {
            let url = URL(string: "https://bm2dx.com/IIDX/notes_radar/notes_radar.json.gz")!
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let decompressedData = data.gunzip() else { return 0 }
            guard let json = try? JSONSerialization.jsonObject(with: decompressedData) as? [String: Any],
                  let midDict = json["mid"] as? [String: String],
                  let notesRadar = json["notes_radar"] as? [String: [String: [[String: Any]]]] else {
                return 0
            }

            var lookup: [String: [String: [Int: (noteCount: Int, values: [String: Double])]]] = [:]
            for (playType, radarTypes) in notesRadar {
                for (radarType, entries) in radarTypes {
                    for entry in entries {
                        guard let mid = entry["mid"] as? String,
                              let difficulty = entry["difficult"] as? Int,
                              let noteCount = entry["note"] as? Int,
                              let value = entry["value"] as? Double else { continue }
                        lookup[playType, default: [:]][mid, default: [:]][difficulty, default: (
                            noteCount: noteCount, values: [:]
                        )].noteCount = noteCount
                        lookup[playType, default: [:]][mid, default: [:]][difficulty, default: (
                            noteCount: noteCount, values: [:]
                        )].values[radarType] = value
                    }
                }
            }

            for (playType, mids) in lookup {
                for (mid, difficulties) in mids {
                    guard let title = midDict[mid] else { continue }
                    for (difficulty, data) in difficulties {
                        let radarData = RadarData(
                            notes: data.values["NOTES"] ?? 0.0,
                            chord: data.values["CHORD"] ?? 0.0,
                            peak: data.values["PEAK"] ?? 0.0,
                            charge: data.values["CHARGE"] ?? 0.0,
                            scratch: data.values["SCRATCH"] ?? 0.0,
                            soflan: data.values["SOFLAN"] ?? 0.0
                        )
                        allEntries.append(ChartRadarData(
                            title: title,
                            playType: playType,
                            difficulty: difficulty,
                            noteCount: data.noteCount,
                            radarData: radarData
                        ))
                    }
                }
            }
        } catch {
            debugPrint("Failed to fetch BM2DX data: \(error)")
        }

        await importer.insertNotesRadarEntries(allEntries)
        progress(1, 1)
        return await IIDXReader().chartRadarDataCount()
    }

    // MARK: - BEMANIWiki (DanceDanceRevolution levels)

    private static func reloadWikiDDR(progress: Progress) async -> Int {
        progress(0, 1)
        let count = await DDRMetadataImporter().reloadBemaniWikiData()
        progress(1, 1)
        return count
    }
}
