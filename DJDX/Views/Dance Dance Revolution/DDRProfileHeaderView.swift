import SwiftSoup
import SwiftUI
import UIKit

struct DDRProfileHeaderView: View {

    @AppStorage(wrappedValue: DDRVersion.world, "Global.DDR.Version") var ddrVersion: DDRVersion

    @State var dancerName: String?
    @State var flareSkill: [DDRPlayStyle: String] = [:]
    @State var flareIcon: [DDRPlayStyle: UIImage] = [:]
    @State var danRank: [DDRPlayStyle: UIImage] = [:]

    let profileHeight: CGFloat = 96.0
    let flareIconHeight: CGFloat = 28.0
    let danRankHeight: CGFloat = 22.0

    var hasData: Bool {
        dancerName != nil || !flareSkill.isEmpty || !flareIcon.isEmpty || !danRank.isEmpty
    }

    var body: some View {
        ZStack {
            if hasData {
                HStack(alignment: .center, spacing: 12.0) {
                    VStack(alignment: .leading, spacing: 2.0) {
                        if let dancerName {
                            Text(verbatim: dancerName)
                                .font(.title2)
                                .fontDesign(.rounded)
                                .fontWeight(.bold)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0.0)
                    ForEach([DDRPlayStyle.single, DDRPlayStyle.double], id: \.self) { style in
                        styleBlock(for: style)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: profileHeight)
            }
        }
        .task {
            loadCachedProfile()
        }
        .onChange(of: ddrVersion) { _, _ in
            loadCachedProfile()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataImported)) { _ in
            Task { await refreshProfile() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileRefreshRequested)) { _ in
            Task { await refreshProfile() }
        }
    }

    @ViewBuilder
    func styleBlock(for style: DDRPlayStyle) -> some View {
        VStack(spacing: 6.0) {
            Text(verbatim: style.rawValue)
                .font(.caption.weight(.bold))
                .italic()
                .foregroundStyle(.secondary)
            HStack(spacing: 4.0) {
                if let icon = flareIcon[style] {
                    Image(uiImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(height: flareIconHeight)
                }
                Text(verbatim: flareSkill[style] ?? "0")
                    .font(.title3.bold())
                    .fontWidth(.condensed)
                    .italic()
                    .monospacedDigit()
            }
            .frame(height: flareIconHeight, alignment: .center)
            if let dan = danRank[style] {
                Image(uiImage: dan)
                    .resizable()
                    .scaledToFit()
                    .frame(height: danRankHeight)
            }
        }
        .frame(minWidth: 64.0)
        .padding(.vertical, 8.0)
        .padding(.horizontal, 10.0)
        .background {
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.0), location: 0.0),
                    .init(color: .white.opacity(0.04), location: 0.45),
                    .init(color: .white.opacity(0.18), location: 0.65),
                    .init(color: .white.opacity(0.5), location: 0.82),
                    .init(color: .white.opacity(1.0), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .cardBackground(cornerRadius: 8.0)
    }

    func refreshProfile() async {
        let request = URLRequest(url: ddrVersion.profilePageURL())
        guard let (htmlData, _) = try? await URLSession.shared.data(for: request),
              let htmlString = String(data: htmlData, encoding: .utf8),
              let document = try? SwiftSoup.parse(htmlString) else { return }

        await parseDancerName(from: document)
        await parseFlareSkill(from: document)
        await parseDanRank(from: document)
    }

    func parseDancerName(from document: Document) async {
        guard let rows = try? document.select("#sougou tr") else { return }
        for row in rows {
            let label = (try? row.select("th").first()?.text())?
                .trimmingCharacters(in: .whitespaces) ?? ""
            guard label == "DANCER NAME" else { continue }
            if let name = try? row.select("td").first()?.text()
                .trimmingCharacters(in: .whitespaces), !name.isEmpty {
                UserDefaults.standard.set(name, forKey: "DDRProfile.DancerName")
                await MainActor.run { self.dancerName = name }
            }
            return
        }
    }

    func parseFlareSkill(from document: Document) async {
        guard let cells = try? document.select("td.total-flare-skill").array() else { return }
        for (index, cell) in cells.enumerated() {
            guard let style = Self.style(forIndex: index) else { continue }
            if let value = try? cell.select(".total-flare-skill-value").first()?.text()
                .trimmingCharacters(in: .whitespaces), !value.isEmpty {
                UserDefaults.standard.set(value, forKey: flareSkillKey(style))
                await MainActor.run { self.flareSkill[style] = value }
            }
            if let src = try? cell.select("img.flare-rank").first()?.attr("src"),
               let url = absoluteURL(src),
               let image = await downloadImage(from: url) {
                saveImage(image.1, named: flareIconFileName(style))
                await MainActor.run { withAnimation { self.flareIcon[style] = image.0 } }
            }
        }
    }

    func parseDanRank(from document: Document) async {
        guard let images = try? document.select(".danrank-grade img").array() else { return }
        for (index, img) in images.enumerated() {
            guard let style = Self.style(forIndex: index) else { continue }
            if let src = try? img.attr("src"),
               let url = absoluteURL(src),
               let image = await downloadImage(from: url) {
                saveImage(image.1, named: danRankFileName(style))
                await MainActor.run { withAnimation { self.danRank[style] = image.0 } }
            }
        }
    }

    static func style(forIndex index: Int) -> DDRPlayStyle? {
        switch index {
        case 0: return .single
        case 1: return .double
        default: return nil
        }
    }

    func absoluteURL(_ src: String) -> URL? {
        guard !src.isEmpty else { return nil }
        if src.hasPrefix("http") { return URL(string: src) }
        return URL(string: src, relativeTo: URL(string: "https://p.eagate.573.jp"))?.absoluteURL
    }

    func downloadImage(from url: URL) async -> (UIImage, Data)? {
        guard let (data, response) = try? await URLSession.shared.data(for: URLRequest(url: url)),
              let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let image = UIImage(data: data) else { return nil }
        return (image, data)
    }

    func flareSkillKey(_ style: DDRPlayStyle) -> String {
        "DDRProfile.FlareSkill.\(style.rawValue)"
    }

    func flareIconFileName(_ style: DDRPlayStyle) -> String {
        "DDRProfile.FlareIcon.\(style.rawValue).png"
    }

    func danRankFileName(_ style: DDRPlayStyle) -> String {
        "DDRProfile.DanRank.\(style.rawValue).png"
    }

    func loadCachedProfile() {
        dancerName = UserDefaults.standard.string(forKey: "DDRProfile.DancerName")
        for style in [DDRPlayStyle.single, .double] {
            if let value = UserDefaults.standard.string(forKey: flareSkillKey(style)) {
                flareSkill[style] = value
            }
            if let icon = loadCachedImage(named: flareIconFileName(style)) {
                flareIcon[style] = icon
            }
            if let dan = loadCachedImage(named: danRankFileName(style)) {
                danRank[style] = dan
            }
        }
    }

    func imageFileURL(named fileName: String) -> URL? {
        guard let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first else { return nil }
        return documentsDirectory.appendingPathComponent(fileName)
    }

    func loadCachedImage(named fileName: String) -> UIImage? {
        guard let fileURL = imageFileURL(named: fileName),
              FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return UIImage(contentsOfFile: fileURL.path)
    }

    func saveImage(_ imageData: Data, named fileName: String) {
        guard let fileURL = imageFileURL(named: fileName) else { return }
        try? imageData.write(to: fileURL)
    }
}
