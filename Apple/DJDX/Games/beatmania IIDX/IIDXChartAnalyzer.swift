import Foundation

actor IIDXChartAnalyzer {

    static let shared = IIDXChartAnalyzer()

    private static let cacheVersion = 6
    private static let endpoint = URL(string: "https://textage-chart-viewer.vercel.app/api/chart")!

    private var profiles: [String: IIDXChartProfile] = [:]
    private var inFlight: [String: Task<IIDXChartProfile?, Never>] = [:]
    private var hasRemovedStaleProfiles = false

    private let cacheDirectory: URL = FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("IIDXChartProfiles", isDirectory: true)

    func profile(for chart: TextageChartViewerChart,
                 difficulty: IIDXLevel,
                 playType: IIDXPlayType) async -> IIDXChartProfile? {
        guard let scoreURL = chart.textageScoreURL(for: difficulty, playType: playType) else { return nil }
        let level = chart.level(for: difficulty, playType: playType)
        let key = [
            "v\(Self.cacheVersion)", String(chart.version), chart.songId,
            playType == .double ? "DP" : "SP", difficulty.code(), String(level)
        ].joined(separator: "_")

        if let profile = profiles[key] {
            return profile
        }
        removeStaleProfilesIfNeeded()
        if let profile = readCachedProfile(key: key) {
            profiles[key] = profile
            return profile
        }
        if let task = inFlight[key] {
            return await task.value
        }

        let task = Task.detached {
            await Self.analyze(scoreURL: scoreURL, playType: playType, level: level)
        }
        inFlight[key] = task
        let profile = await task.value
        inFlight[key] = nil
        if let profile {
            profiles[key] = profile
            writeCachedProfile(profile, key: key)
        }
        return profile
    }

    private static func analyze(scoreURL: URL, playType: IIDXPlayType, level: Int) async -> IIDXChartProfile? {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["url": scoreURL.absoluteString])
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode(ChartResponse.self, from: data) else {
            return nil
        }
        return IIDXChartProfile(notes: decoded.data.notes,
                                bpmChanges: decoded.data.bpmChanges,
                                playType: playType,
                                level: level)
    }

    private func removeStaleProfilesIfNeeded() {
        guard !hasRemovedStaleProfiles else { return }
        hasRemovedStaleProfiles = true
        let currentPrefix = "v\(Self.cacheVersion)_".addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        let files = (try? FileManager.default.contentsOfDirectory(at: cacheDirectory,
                                                                  includingPropertiesForKeys: nil)) ?? []
        for file in files where !file.lastPathComponent.hasPrefix(currentPrefix) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func cacheFileURL(key: String) -> URL {
        cacheDirectory.appendingPathComponent(key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key)
            .appendingPathExtension("json")
    }

    private func readCachedProfile(key: String) -> IIDXChartProfile? {
        guard let data = try? Data(contentsOf: cacheFileURL(key: key)) else { return nil }
        return try? JSONDecoder().decode(IIDXChartProfile.self, from: data)
    }

    private func writeCachedProfile(_ profile: IIDXChartProfile, key: String) {
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(profile) else { return }
        try? data.write(to: cacheFileURL(key: key), options: .atomic)
    }
}

private struct ChartResponse: Decodable {
    struct ChartData: Decodable {
        let notes: [IIDXChartNote]
        let bpmChanges: [IIDXChartBPMChange]
    }
    let data: ChartData
}
