import SwiftSoup
import SwiftUI
import UIKit

struct IIDXProfileHeaderView: View {

    @AppStorage(wrappedValue: IIDXVersion.sparkleShower, "Global.IIDX.Version") var iidxVersion: IIDXVersion
    @AppStorage(wrappedValue: .single, "ScoresView.PlayTypeFilter") var playTypeToShow: IIDXPlayType

    @State var qproImage: UIImage?
    @State var djName: String?
    @State var spRank: String?
    @State var dpRank: String?
    @State var spRadarData: RadarData?
    @State var dpRadarData: RadarData?

    let profileHeight: CGFloat = 120.0

    var hasData: Bool {
        qproImage != nil || djName != nil || spRadarData != nil || dpRadarData != nil
    }

    var rankText: String? {
        let rank: String?
        switch playTypeToShow {
        case .single: rank = spRank
        case .double: rank = dpRank
        }
        guard let rank, rank != "--" else { return nil }
        return rank
    }

    var body: some View {
        ZStack {
            if hasData {
                HStack(alignment: .center, spacing: 12.0) {
                    if let qproImage {
                        Image(uiImage: qproImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: profileHeight)
                    }
                    if djName != nil || rankText != nil {
                        VStack(alignment: .leading, spacing: 2.0) {
                            if let djName {
                                Text(verbatim: djName)
                                    .font(.system(size: 16.0, weight: .semibold))
                                    .lineLimit(1)
                            }
                            if let rankText {
                                Text(verbatim: rankText)
                                    .font(.system(size: 14.0))
                                    .lineLimit(1)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .fontWidth(.condensed)
                    }
                    Spacer(minLength: 0)
                    if spRadarData != nil || dpRadarData != nil {
                        MoreNotesRadarView(
                            spRadarData: spRadarData,
                            dpRadarData: dpRadarData,
                            maxHeight: profileHeight,
                            radarFontSize: 8.0,
                            listFontSize: 10.0
                        )
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: profileHeight)
            }
        }
        .task {
            loadRadarData()
            loadProfileData()
            qproImage = loadQproImage()
        }
        .onChange(of: iidxVersion) { _, _ in
            loadRadarData()
            loadProfileData()
            qproImage = loadQproImage()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataImported)) { _ in
            Task { await refreshStatusPageData() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileRefreshRequested)) { _ in
            Task { await refreshStatusPageData() }
        }
    }

    func refreshStatusPageData() async {
        qproImage = loadQproImage()
        if qproImage == nil {
            await downloadStatusPageData()
            withAnimation {
                qproImage = loadQproImage()
            }
        } else {
            await downloadStatusPageData()
        }
    }

    func loadQproImage() -> UIImage? {
        let fileURL = SharedContainer.imagesURL.appendingPathComponent("Qpro.png")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return UIImage(contentsOfFile: fileURL.path)
        } else {
            return nil
        }
    }

    func downloadStatusPageData() async {
        let baseURLString = "https://p.eagate.573.jp"
        let request = URLRequest(url: iidxVersion.statusPageURL())

        do {
            let (htmlData, _) = try await URLSession.shared.data(for: request)
            guard let htmlString = String(data: htmlData, encoding: .utf8) else { return }

            let document = try SwiftSoup.parse(htmlString)

            if let imgElement = try document.select("div.qpro-img img").first() {
                let extractedPath = try imgElement.attr("src")
                if let imageURL = URL(string: baseURLString + extractedPath) {
                    let imageRequest = URLRequest(url: imageURL)
                    let (imageData, response) = try await URLSession.shared.data(for: imageRequest)

                    if let httpResponse = response as? HTTPURLResponse,
                       (200...299).contains(httpResponse.statusCode) {
                        try? FileManager.default.createDirectory(
                            at: SharedContainer.imagesURL, withIntermediateDirectories: true
                        )
                        let fileURL = SharedContainer.imagesURL.appendingPathComponent("Qpro.png")
                        try? imageData.write(to: fileURL)
                    }
                }
            }

            try parseProfileData(from: document)

            let radarCategories = try document.select("div#notes div.rank-cat")
            for category in radarCategories {
                guard let spanElement = try category.select("span").first() else { continue }
                let playTypeLabel = try spanElement.text()

                let listItems = try category.select("ul li")
                var values: [String: Double] = [:]
                for item in listItems {
                    let paragraphs = try item.select("p")
                    if paragraphs.size() == 2 {
                        let key = try paragraphs.get(0).text()
                        let valueString = try paragraphs.get(1).text()
                        if let value = Double(valueString) {
                            values[key] = value
                        }
                    }
                }

                let radarData = RadarData(
                    notes: values["NOTES"] ?? 0.0,
                    chord: values["CHORD"] ?? 0.0,
                    peak: values["PEAK"] ?? 0.0,
                    charge: values["CHARGE"] ?? 0.0,
                    scratch: values["SCRATCH"] ?? 0.0,
                    soflan: values["SOF-LAN"] ?? 0.0
                )

                if playTypeLabel == "SP" {
                    spRadarData = radarData
                } else if playTypeLabel == "DP" {
                    dpRadarData = radarData
                }
            }

            saveRadarData()
            saveProfileData()
            await WidgetDataPublisher.shared.publishRadar()
            await WidgetDataPublisher.shared.publishQpro()
            IIDXSessionWorkoutBridge.shared.syncProfileToWatch()
        } catch {
            return
        }
    }

    func saveRadarData() {
        let defaults = SharedContainer.defaults
        if let spData = spRadarData {
            defaults.set(spData.notes, forKey: "NotesRadar.SP.Notes")
            defaults.set(spData.chord, forKey: "NotesRadar.SP.Chord")
            defaults.set(spData.peak, forKey: "NotesRadar.SP.Peak")
            defaults.set(spData.charge, forKey: "NotesRadar.SP.Charge")
            defaults.set(spData.scratch, forKey: "NotesRadar.SP.Scratch")
            defaults.set(spData.soflan, forKey: "NotesRadar.SP.Soflan")
        }
        if let dpData = dpRadarData {
            defaults.set(dpData.notes, forKey: "NotesRadar.DP.Notes")
            defaults.set(dpData.chord, forKey: "NotesRadar.DP.Chord")
            defaults.set(dpData.peak, forKey: "NotesRadar.DP.Peak")
            defaults.set(dpData.charge, forKey: "NotesRadar.DP.Charge")
            defaults.set(dpData.scratch, forKey: "NotesRadar.DP.Scratch")
            defaults.set(dpData.soflan, forKey: "NotesRadar.DP.Soflan")
        }
    }

    func loadRadarData() {
        let defaults = SharedContainer.defaults
        if defaults.object(forKey: "NotesRadar.SP.Notes") != nil {
            spRadarData = RadarData(
                notes: defaults.double(forKey: "NotesRadar.SP.Notes"),
                chord: defaults.double(forKey: "NotesRadar.SP.Chord"),
                peak: defaults.double(forKey: "NotesRadar.SP.Peak"),
                charge: defaults.double(forKey: "NotesRadar.SP.Charge"),
                scratch: defaults.double(forKey: "NotesRadar.SP.Scratch"),
                soflan: defaults.double(forKey: "NotesRadar.SP.Soflan")
            )
        }
        if defaults.object(forKey: "NotesRadar.DP.Notes") != nil {
            dpRadarData = RadarData(
                notes: defaults.double(forKey: "NotesRadar.DP.Notes"),
                chord: defaults.double(forKey: "NotesRadar.DP.Chord"),
                peak: defaults.double(forKey: "NotesRadar.DP.Peak"),
                charge: defaults.double(forKey: "NotesRadar.DP.Charge"),
                scratch: defaults.double(forKey: "NotesRadar.DP.Scratch"),
                soflan: defaults.double(forKey: "NotesRadar.DP.Soflan")
            )
        }
    }

    func parseProfileData(from document: SwiftSoup.Document) throws {
        for row in try document.select("div.dj-profile table tr") {
            let cells = try row.select("td")
            if cells.size() == 2, try cells.get(0).text() == "DJ NAME" {
                djName = try cells.get(1).text()
            }
        }

        for rankSection in try document.select("div.dj-rank") {
            guard try rankSection.select("div.cat-name").first()?.text() == "段位認定" else { continue }
            for category in try rankSection.select("div.rank-cat") {
                guard let playTypeLabel = try category.select("span").first()?.text() else { continue }
                let children = category.children()
                guard children.size() == 2 else { continue }
                let rank = try children.get(1).text()
                if playTypeLabel == "SP" {
                    spRank = rank
                } else if playTypeLabel == "DP" {
                    dpRank = rank
                }
            }
        }
    }

    func saveProfileData() {
        let defaults = UserDefaults.standard
        defaults.set(djName, forKey: "Profile.IIDX.DJName")
        defaults.set(spRank, forKey: "Profile.IIDX.SPRank")
        defaults.set(dpRank, forKey: "Profile.IIDX.DPRank")
    }

    func loadProfileData() {
        let defaults = UserDefaults.standard
        djName = defaults.string(forKey: "Profile.IIDX.DJName")
        spRank = defaults.string(forKey: "Profile.IIDX.SPRank")
        dpRank = defaults.string(forKey: "Profile.IIDX.DPRank")
    }
}
