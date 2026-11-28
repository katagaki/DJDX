import Foundation
import SwiftSoup

enum ExternalDataSourceID: String, CaseIterable {
    case textage
    case textageChartViewer
    case sdvxIn
    case wikiIidx
    case bm2dx
    case wikiDdr
}

@MainActor
struct ExternalDataReloader {
    typealias Progress = @MainActor @Sendable (Int, Int) -> Void

    @discardableResult
    static func reload(
        _ id: ExternalDataSourceID,
        iidxVersion: IIDXVersion,
        progress: @escaping Progress = { _, _ in }
    ) async -> Int {
        let count: Int = switch id {
        case .textage: await refreshingInfinitasCharts(await reloadTextage(progress: progress))
        case .textageChartViewer: await reloadTextageChartViewer(progress: progress)
        case .sdvxIn: await reloadSDVXIn(progress: progress)
        case .wikiIidx: await refreshingInfinitasCharts(await reloadWikiIIDX(version: iidxVersion, progress: progress))
        case .bm2dx: await reloadBM2DX(progress: progress)
        case .wikiDdr: await reloadWikiDDR(progress: progress)
        }
        if !Task.isCancelled {
            NotificationCenter.default.post(name: .externalDataChanged, object: nil)
        }
        return count
    }

    static func delete(_ id: ExternalDataSourceID) async {
        switch id {
        case .textage:
            await TextageImporter().deleteAllCharts()
            _ = await refreshingInfinitasCharts(0)
        case .textageChartViewer:
            await TextageChartViewerImporter().deleteAllCharts()
        case .sdvxIn:
            await SDVXInImporter().deleteAllCharts()
        case .wikiIidx:
            await IIDXImporter().deleteAllSongs()
            _ = await refreshingInfinitasCharts(0)
        case .bm2dx:
            await IIDXImporter().deleteAllNotesRadarEntries()
        case .wikiDdr:
            await DDRMetadataImporter().deleteAllSongMeta()
        }
        NotificationCenter.default.post(name: .externalDataChanged, object: nil)
    }

    private static func refreshingInfinitasCharts(_ count: Int) async -> Int {
        await IIDXImporter().refreshInfinitasChartData()
        await MainActor.run {
            NotificationCenter.default.post(name: .dataImported, object: nil)
        }
        return count
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

        guard !Task.isCancelled, let titleTableText, let accessTableText else {
            return await IIDXReader().textageChartCount()
        }
        let charts = TextageTableParser.charts(titleTableText: titleTableText,
                                               accessTableText: accessTableText)
        await TextageImporter().replaceAllCharts(charts)
        return await IIDXReader().textageChartCount()
    }

    // MARK: - Textage Chart Viewer

    private static func reloadTextageChartViewer(progress: Progress) async -> Int {
        progress(0, 1)
        guard let url = URL(string: "https://textage-chart-viewer.vercel.app/api/songs"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let response = try? JSONDecoder().decode(TextageChartViewerSongsResponse.self, from: data) else {
            return 0
        }

        var charts: [TextageChartViewerChart] = []
        for song in response.data {
            let chart = TextageChartViewerChart(
                songId: song.songId,
                version: song.version,
                title: song.title + (song.subtitle ?? ""),
                spBeginner: song.levels.spBeginner,
                spNormal: song.levels.spNormal,
                spHyper: song.levels.spHyper,
                spAnother: song.levels.spAnother,
                spLeggendaria: song.levels.spLeggendaria,
                dpBeginner: song.levels.dpBeginner,
                dpNormal: song.levels.dpNormal,
                dpHyper: song.levels.dpHyper,
                dpAnother: song.levels.dpAnother,
                dpLeggendaria: song.levels.dpLeggendaria
            )
            let hasAnyChart = [
                chart.spBeginner, chart.spNormal, chart.spHyper, chart.spAnother, chart.spLeggendaria,
                chart.dpBeginner, chart.dpNormal, chart.dpHyper, chart.dpAnother, chart.dpLeggendaria
            ].contains { $0 > 0 }
            if hasAnyChart, !chart.title.isEmpty {
                charts.append(chart)
            }
        }

        guard !Task.isCancelled else { return await IIDXReader().textageChartViewerChartCount() }
        await TextageChartViewerImporter().replaceAllCharts(charts)
        progress(1, 1)
        return await IIDXReader().textageChartViewerChartCount()
    }

    // MARK: - sdvx.in

    private static func reloadSDVXIn(progress: Progress) async -> Int {
        var charts: [SDVXInChart] = []
        let fileCount = await sdvxInSongFileCount()

        progress(0, fileCount)
        for fileNumber in 1...fileCount {
            guard !Task.isCancelled else { return await SDVXReader().sdvxInChartCount() }
            defer { progress(fileNumber, fileCount) }
            let fileSlug = String(format: "%02d", fileNumber)
            guard let url = URL(string: "https://sdvx.in/sdvx/_/json/songs\(fileSlug).json"),
                  let (data, _) = try? await URLSession.shared.data(from: url),
                  let songs = try? JSONDecoder().decode([SDVXInSong].self, from: data) else { continue }
            charts.append(contentsOf: songs.flatMap(\.charts))
        }

        guard !Task.isCancelled else { return await SDVXReader().sdvxInChartCount() }
        await SDVXInImporter().replaceAllCharts(charts)
        return await SDVXReader().sdvxInChartCount()
    }

    private static func sdvxInSongFileCount() async -> Int {
        let fallbackCount = 7
        guard let url = URL(string: "https://sdvx.in/sdvx/_/data.js"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let script = String(data: data, encoding: .utf8),
              let match = script.firstMatch(of: /FILE_COUNT:\s*(\d+)/),
              let count = Int(match.1), count > 0 else { return fallbackCount }
        return count
    }

    // MARK: - BEMANIWiki (beatmania IIDX note counts)

    private static func reloadWikiIIDX(version: IIDXVersion, progress: Progress) async -> Int {
        let importer = IIDXImporter()
        progress(0, 2)
        var iidxSongs: [IIDXSong] = []
        iidxSongs.append(contentsOf: await songsForLatestVersion(version: version))
        guard !Task.isCancelled else { return await IIDXReader().bemaniWikiSongCount() }
        progress(1, 2)
        iidxSongs.append(contentsOf: await songsForExistingVersions(version: version))
        guard !Task.isCancelled else { return await IIDXReader().bemaniWikiSongCount() }
        let levels = await levelsForLatestVersion(version: version)
        guard !Task.isCancelled else { return await IIDXReader().bemaniWikiSongCount() }
        for song in iidxSongs {
            if let entry = levels[song.title.compact] {
                song.spLevels = entry.single
                song.dpLevels = entry.double
            }
        }
        progress(2, 2)
        await importer.deleteAllSongs()
        await importer.insertSongs(iidxSongs)
        await Task.detached(priority: .utility) {
            IIDXSessionCaptureProcessor.backfillDifficultiesFromBEMANIWiki()
        }.value
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
        var allEntries: [ChartRadarData] = []

        do {
            let url = URL(string: "https://bm2dx.com/IIDX/notes_radar/notes_radar_data.json.gz")!
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let decompressedData = data.gunzip() else { return 0 }
            guard let json = try? JSONSerialization.jsonObject(with: decompressedData) as? [String: Any],
                  let midDict = json["mid"] as? [String: String],
                  let radarSP = json["radar_sp"] as? [[Any]],
                  let radarDP = json["radar_dp"] as? [[Any]],
                  !radarSP.isEmpty, !radarDP.isEmpty else {
                return 0
            }

            for (playType, rows) in [("SP", radarSP), ("DP", radarDP)] {
                for row in rows {
                    guard row.count == 10,
                          let mid = row[0] as? String,
                          let title = midDict[mid],
                          let difficulty = row[1] as? Int,
                          let noteCount = row[3] as? Int,
                          let notes = row[4] as? Double,
                          let chord = row[5] as? Double,
                          let peak = row[6] as? Double,
                          let charge = row[7] as? Double,
                          let scratch = row[8] as? Double,
                          let soflan = row[9] as? Double else { return 0 }

                    guard notes + chord + peak + charge + scratch + soflan > 0.0 else { continue }
                    allEntries.append(ChartRadarData(
                        title: title,
                        playType: playType,
                        difficulty: difficulty,
                        noteCount: noteCount,
                        radarData: RadarData(notes: notes, chord: chord, peak: peak,
                                             charge: charge, scratch: scratch, soflan: soflan)
                    ))
                }
            }
        } catch {
            debugPrint("Failed to fetch BM2DX data: \(error)")
        }

        guard !Task.isCancelled, await importer.replaceAllNotesRadarEntries(allEntries) else {
            return await IIDXReader().chartRadarDataCount()
        }
        progress(1, 1)
        return await IIDXReader().chartRadarDataCount()
    }

    // MARK: - BEMANIWiki (DanceDanceRevolution levels)

    private static func reloadWikiDDR(progress: @escaping Progress) async -> Int {
        await DDRMetadataImporter().reloadBemaniWikiData(progress: progress)

    }
}

private struct TextageChartViewerSongsResponse: Decodable {
    struct Song: Decodable {
        var songId: String
        var version: Int
        var title: String
        var subtitle: String?
        var levels: Levels
    }

    struct Levels: Decodable {
        var spBeginner: Int
        var spNormal: Int
        var spHyper: Int
        var spAnother: Int
        var spLeggendaria: Int
        var dpBeginner: Int
        var dpNormal: Int
        var dpHyper: Int
        var dpAnother: Int
        var dpLeggendaria: Int
    }

    var data: [Song]
}

@MainActor
extension ExternalDataReloader {
    static func levelsForLatestVersion(version: IIDXVersion) async -> [String: IIDXSongLevels] {
        do {
            var levels: [String: IIDXSongLevels] = [:]
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
                let scope = indexOfHeader.map {
                    Elements(Array(documentBody.children()[0..<$0]))
                } ?? documentBody.children()
                if let tables = try? scope.select("div.ie5") {
                    for table in tables {
                        guard let tableRows = try? table.select("tr") else { continue }
                        for tableRow in tableRows {
                            guard let tableRowColumns = try? tableRow.select("td"),
                                  tableRowColumns.count == 13 else { continue }
                            let columnData = tableRowColumns.compactMap { try? $0.text() }
                            if let parsed = IIDXSong.parseLevelRow(columnData) {
                                levels[parsed.compactTitle] = parsed.levels
                            }
                        }
                    }
                }
            }
            return levels
        } catch {
            debugPrint(error.localizedDescription)
            return [:]
        }
    }
}
