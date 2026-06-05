import Komponents
import SwiftSoup
import SwiftUI

// swiftlint:disable:next type_body_length
struct MoreExternalDataSources: View {

    @Environment(\.openURL) var openURL
    @Environment(\.dismiss) var dismiss
    
    @AppStorage(wrappedValue: false, "ExternalData.Textage.Enabled") var isTextageEnabled: Bool
    @AppStorage(wrappedValue: false, "ExternalData.SDVXIn.Enabled") var isSDVXInEnabled: Bool
    @AppStorage(wrappedValue: false, "ExternalData.BemaniWiki2nd.Enabled") var isBemaniWikiEnabled: Bool
    @AppStorage(wrappedValue: false, "ExternalData.BM2DX.Enabled") var isBM2DXEnabled: Bool
    @AppStorage(wrappedValue: IIDXVersion.sparkleShower, "Global.IIDX.Version") var iidxVersion: IIDXVersion

    @State var bemaniWikiEntryCount: Int = 0
    @State var bm2dxEntryCount: Int = 0
    @State var sdvxInEntryCount: Int = 0
    @State var textageEntryCount: Int = 0

    @State var isBemaniWikiReloadCompleted: Bool = false
    @State var isBM2DXReloadCompleted: Bool = false
    @State var isSDVXInReloadCompleted: Bool = false
    @State var isTextageReloadCompleted: Bool = false
    @State var dataImported: Int = 0
    @State var dataTotal: Int = 2
    @State var reloadingSource: ExternalDataReloadSource?

    enum ExternalDataReloadSource {
        case bemaniWiki, bm2dx, sdvxIn, textage
    }

    let fetcher = IIDXReader()
    let importer = IIDXImporter()
    let sdvxFetcher = SDVXReader()
    let sdvxInImporter = SDVXInImporter()
    let textageImporter = TextageImporter()

    var body: some View {
        List {
            textageSection()
            sdvxInSection()
            bemaniWikiSection()
            bm2dxSection()
        }
        .navigationTitle("More.ExternalData.Header")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if #available(iOS 26.0, *) {
                    Button(role: .close) {
                        dismiss()
                    }
                } else {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .tint(.primary)
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
        }
        .task {
            bemaniWikiEntryCount = await fetcher.bemaniWikiSongCount()
            bm2dxEntryCount = await fetcher.chartRadarDataCount()
            sdvxInEntryCount = await sdvxFetcher.sdvxInChartCount()
            textageEntryCount = await fetcher.textageChartCount()
        }
        .alert(
            "Alert.ExternalData.Completed.Title",
            isPresented: $isBemaniWikiReloadCompleted,
            actions: {
                Button("Shared.OK", role: .cancel) {
                    isBemaniWikiReloadCompleted = false
                }
            },
            message: {
                Text("Alert.ExternalData.Completed.Text.\(bemaniWikiEntryCount)")
            }
        )
        .alert(
            "Alert.ExternalData.Completed.Title",
            isPresented: $isBM2DXReloadCompleted,
            actions: {
                Button("Shared.OK", role: .cancel) {
                    isBM2DXReloadCompleted = false
                }
            },
            message: {
                Text("Alert.ExternalData.Completed.Text.\(bm2dxEntryCount)")
            }
        )
        .alert(
            "Alert.ExternalData.Completed.Title",
            isPresented: $isSDVXInReloadCompleted,
            actions: {
                Button("Shared.OK", role: .cancel) {
                    isSDVXInReloadCompleted = false
                }
            },
            message: {
                Text("Alert.ExternalData.Completed.Text.\(sdvxInEntryCount)")
            }
        )
        .alert(
            "Alert.ExternalData.Completed.Title",
            isPresented: $isTextageReloadCompleted,
            actions: {
                Button("Shared.OK", role: .cancel) {
                    isTextageReloadCompleted = false
                }
            },
            message: {
                Text("Alert.ExternalData.Completed.Text.\(textageEntryCount)")
            }
        )
    }

    @ViewBuilder
    private func reloadIndicator(for source: ExternalDataReloadSource) -> some View {
        if reloadingSource == source {
            switch source {
            case .bm2dx:
                ProgressView()
            default:
                ProgressDonut(progress: dataTotal > 0 ? Double(dataImported) / Double(dataTotal) : 0.0)
            }
        }
    }

    // MARK: - BEMANIWiki 2nd

    @ViewBuilder
    private func bemaniWikiSection() -> some View {
        Section {
            Toggle(isOn: $isBemaniWikiEnabled) {
                Text("More.ExternalData.BemaniWiki2nd.Description")
            }
            if isBemaniWikiEnabled {
                HStack {
                    Button("More.ExternalData.UpdateData") {
                        reloadingSource = .bemaniWiki
                        Task {
                            await reloadBemaniWikiData()
                            reloadingSource = nil
                            isBemaniWikiReloadCompleted = true
                        }
                    }
                    .disabled(reloadingSource != nil)
                    Spacer()
                    reloadIndicator(for: .bemaniWiki)
                }
                HStack {
                    Text("More.ExternalData.BemaniWiki2nd.EntryCount")
                    Spacer()
                    Text(verbatim: "\(bemaniWikiEntryCount)")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            ListSectionHeader(text: "More.ExternalData.BemaniWiki2nd")
                .font(.body)
        } footer: {
            Text("More.ExternalData.BemaniWiki2nd.Footer") +
            Text(" ") +
            Text("[\(String(localized: "More.ExternalData.ViewSource"))](https://bemaniwiki.com)")
        }
    }

    // MARK: - bm2dx.com

    @ViewBuilder
    private func bm2dxSection() -> some View {
        Section {
            Toggle(isOn: $isBM2DXEnabled) {
                Text("More.ExternalData.BM2DX.Description")
            }
            if isBM2DXEnabled {
                HStack {
                    Button("More.ExternalData.UpdateData") {
                        reloadingSource = .bm2dx
                        Task {
                            await reloadBM2DXData()
                            reloadingSource = nil
                            isBM2DXReloadCompleted = true
                        }
                    }
                    .disabled(reloadingSource != nil)
                    Spacer()
                    reloadIndicator(for: .bm2dx)
                }
                HStack {
                    Text("More.ExternalData.BM2DX.EntryCount")
                    Spacer()
                    Text(verbatim: "\(bm2dxEntryCount)")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            ListSectionHeader(text: "More.ExternalData.BM2DX")
                .font(.body)
        } footer: {
            Text("More.ExternalData.BM2DX.Footer") +
            Text(" ") +
            Text("[\(String(localized: "More.ExternalData.ViewSource"))](https://bm2dx.com/IIDX/notes_radar/)")
        }
    }

    // MARK: - sdvx.in

    @ViewBuilder
    private func sdvxInSection() -> some View {
        Section {
            Toggle(isOn: $isSDVXInEnabled) {
                Text("More.ExternalData.SDVXIn.Description")
            }
            if isSDVXInEnabled {
                HStack {
                    Button("More.ExternalData.UpdateData") {
                        reloadingSource = .sdvxIn
                        Task {
                            await reloadSDVXInData()
                            reloadingSource = nil
                            isSDVXInReloadCompleted = true
                        }
                    }
                    .disabled(reloadingSource != nil)
                    Spacer()
                    reloadIndicator(for: .sdvxIn)
                }
                HStack {
                    Text("More.ExternalData.SDVXIn.EntryCount")
                    Spacer()
                    Text(verbatim: "\(sdvxInEntryCount)")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            ListSectionHeader(text: "More.ExternalData.SDVXIn")
                .font(.body)
        } footer: {
            Text("More.ExternalData.SDVXIn.Footer") +
            Text(" ") +
            Text("[\(String(localized: "More.ExternalData.ViewSource"))](https://sdvx.in)")
        }
    }

    // MARK: - Textage

    @ViewBuilder
    private func textageSection() -> some View {
        Section {
            Toggle(isOn: $isTextageEnabled) {
                Text("More.ExternalData.Textage.Description")
            }
            if isTextageEnabled {
                HStack {
                    Button("More.ExternalData.UpdateData") {
                        reloadingSource = .textage
                        Task {
                            await reloadTextageData()
                            reloadingSource = nil
                            isTextageReloadCompleted = true
                        }
                    }
                    .disabled(reloadingSource != nil)
                    Spacer()
                    reloadIndicator(for: .textage)
                }
                HStack {
                    Text("More.ExternalData.Textage.EntryCount")
                    Spacer()
                    Text(verbatim: "\(textageEntryCount)")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            ListSectionHeader(text: "More.ExternalData.Textage")
                .font(.body)
        } footer: {
            Text("More.ExternalData.Textage.Footer") +
            Text(" ") +
            Text("[\(String(localized: "More.ExternalData.ViewSource"))](https://textage.cc)")
        }
    }

    // MARK: - Textage Data Loading

    func reloadTextageData() async {
        dataTotal = 2
        dataImported = 0

        guard let titleURL = URL(string: "https://textage.cc/score/titletbl.js"),
              let accessURL = URL(string: "https://textage.cc/score/actbl.js") else { return }

        var titleTableText: String?
        var accessTableText: String?

        if let (data, _) = try? await URLSession.shared.data(from: titleURL) {
            titleTableText = data.decodedAsTextageTable()
        }
        dataImported += 1

        if let (data, _) = try? await URLSession.shared.data(from: accessURL) {
            accessTableText = data.decodedAsTextageTable()
        }
        dataImported += 1

        guard let titleTableText, let accessTableText else { return }
        let charts = TextageTableParser.charts(titleTableText: titleTableText,
                                               accessTableText: accessTableText)
        await textageImporter.replaceAllCharts(charts)
        textageEntryCount = await fetcher.textageChartCount()
    }

    // MARK: - sdvx.in Data Loading

    func reloadSDVXInData() async {
        var charts: [SDVXInChart] = []
        let pattern = "SORT([0-9]{5})([NAEMnaem])\\(\\);</script><!--(.*?)-->"
        let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])

        dataTotal = 20
        dataImported = 0
        for level in 1...20 {
            defer { dataImported += 1 }
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

        await sdvxInImporter.replaceAllCharts(charts)
        sdvxInEntryCount = await sdvxFetcher.sdvxInChartCount()
    }

    // MARK: - BEMANIWiki Data Loading

    func reloadBemaniWikiData() async {
        dataTotal = 2
        dataImported = 0
        await importer.deleteAllSongs()
        var iidxSongs: [IIDXSong] = []
        iidxSongs.append(contentsOf: await reloadBemaniWikiDataForLatestVersion())
        dataImported += 1
        iidxSongs.append(contentsOf: await reloadBemaniWikiDataForExistingVersions())
        dataImported += 1
        await importer.insertSongs(iidxSongs)
        bemaniWikiEntryCount = await fetcher.bemaniWikiSongCount()
    }

    func reloadBemaniWikiDataForLatestVersion() async -> [IIDXSong] {
        do {
            var iidxSongsFromWiki: [IIDXSong] = []
            let (data, _) = try await URLSession.shared.data(from: iidxVersion.bemaniWikiLatestVersionPageURL())
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
                            debugPrint(table)
                            if let tableRows = try? table.select("tr") {
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

    // MARK: - BM2DX Data Loading

    func reloadBM2DXData() async {
        await importer.deleteAllNotesRadar()
        var allEntries: [ChartRadarData] = []

        do {
            let url = URL(string: "https://bm2dx.com/IIDX/notes_radar/notes_radar.json.gz")!
            let (data, _) = try await URLSession.shared.data(from: url)

            guard let decompressedData = data.gunzip() else {
                return
            }

            guard let json = try? JSONSerialization.jsonObject(with: decompressedData) as? [String: Any],
                  let midDict = json["mid"] as? [String: String],
                  let notesRadar = json["notes_radar"] as? [String: [String: [[String: Any]]]] else {
                return
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
                            noteCount: noteCount,
                            values: [:]
                        )].noteCount = noteCount
                        lookup[playType, default: [:]][mid, default: [:]][difficulty, default: (
                            noteCount: noteCount,
                            values: [:]
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
        bm2dxEntryCount = await fetcher.chartRadarDataCount()
    }
}
