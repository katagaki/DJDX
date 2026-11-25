import SwiftSoup
import SwiftUI

struct GITADORAProfileHeaderView: View {

    @AppStorage(wrappedValue: GITADORAVersion.galaxyWaveDelta, "Global.GITADORA.Version")
    var gitadoraVersion: GITADORAVersion

    @State var playerName: String?
    @State var skills: [String: String] = [:]

    let profileHeight: CGFloat = 60.0
    let gameTypes: [(gameType: String, label: String)] = [("gf", "GuitarFreaks"), ("dm", "DrumMania")]

    var hasData: Bool {
        playerName != nil || !skills.isEmpty
    }

    var body: some View {
        ZStack {
            if hasData {
                HStack(alignment: .center, spacing: 12.0) {
                    VStack(alignment: .leading, spacing: 2.0) {
                        if let playerName {
                            Text(verbatim: playerName)
                                .font(.title2)
                                .fontDesign(.rounded)
                                .fontWeight(.bold)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0.0)
                    ForEach(gameTypes, id: \.gameType) { entry in
                        skillBlock(label: entry.label, value: skills[entry.gameType] ?? "0.00")
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: profileHeight)
            }
        }
        .task {
            loadCachedProfile()
        }
        .onChange(of: gitadoraVersion) { _, _ in
            loadCachedProfile()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataImported)) { _ in
            loadCachedProfile()
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileRefreshRequested)) { _ in
            Task { await refreshProfile() }
        }
    }

    @ViewBuilder
    func skillBlock(label: String, value: String) -> some View {
        VStack(spacing: 6.0) {
            HStack(spacing: 3.0) {
                Text(verbatim: label)
                Text("Shared.GITADORA.Skill")
            }
            .font(.caption2.weight(.bold))
            .italic()
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            Text(verbatim: value)
                .font(.title3.bold())
                .fontWidth(.condensed)
                .italic()
                .monospacedDigit()
                .frame(height: 24.0, alignment: .center)
        }
        .frame(minWidth: 64.0)
        .padding(.vertical, 8.0)
        .padding(.horizontal, 10.0)
        .cardBackground(cornerRadius: 8.0)
    }

    func refreshProfile() async {
        if let document = await fetchDocument(gitadoraVersion.profilePageURL()),
           let name = try? document.select(".profile_name_frame").first()?.text()
            .trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            UserDefaults.standard.set(name, forKey: GITADORAImporter.playerNameKey)
            await MainActor.run { self.playerName = name }
        }
        for entry in gameTypes {
            var total = 0.0
            var hasTable = false
            for skillType in [0, 1] {
                guard let document = await fetchDocument(
                    gitadoraVersion.skillPageURL(gameType: entry.gameType, skillType: skillType)
                ), let cells = try? document.select(".skill_table_tb td.skill_cell") else { continue }
                hasTable = true
                for cell in cells {
                    total += Self.leadingNumber(in: (try? cell.text()) ?? "")
                }
            }
            guard hasTable else { continue }
            let value = String(format: "%.2f", total)
            UserDefaults.standard.set(value, forKey: GITADORAImporter.skillKey(gameType: entry.gameType))
            await MainActor.run { self.skills[entry.gameType] = value }
        }
    }

    static func leadingNumber(in text: String) -> Double {
        guard let range = text.range(of: #"\d+(\.\d+)?"#, options: .regularExpression) else { return 0.0 }
        return Double(text[range]) ?? 0.0
    }

    func fetchDocument(_ url: URL) async -> SwiftSoup.Document? {
        guard let (data, response) = try? await URLSession.shared.data(for: URLRequest(url: url)),
              let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              !(httpResponse.url?.absoluteString.contains("login.html") ?? false) else { return nil }
        let isShiftJIS = httpResponse.textEncodingName?.lowercased().contains("shift") ?? false
        let html = isShiftJIS
            ? String(data: data, encoding: .shiftJIS)
            : (String(data: data, encoding: .utf8) ?? String(data: data, encoding: .shiftJIS))
        guard let html else { return nil }
        return try? SwiftSoup.parse(html)
    }

    func loadCachedProfile() {
        playerName = UserDefaults.standard.string(forKey: GITADORAImporter.playerNameKey)
        var cachedSkills: [String: String] = [:]
        for entry in gameTypes {
            if let value = UserDefaults.standard.string(forKey: GITADORAImporter.skillKey(gameType: entry.gameType)) {
                cachedSkills[entry.gameType] = value
            }
        }
        skills = cachedSkills
    }
}
