import Foundation

actor IIDXChartAnalyzer {

    static let shared = IIDXChartAnalyzer()

    private static let endpoint = URL(string: "https://textage-chart-viewer.vercel.app/api/chart")!

    private var profiles: [String: IIDXChartProfile] = [:]
    private var inFlight: [String: Task<(IIDXChartProfile, IIDXChartData)?, Never>] = [:]
    private var hasRemovedLegacyCache = false

    private let cachesDirectory: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    private var profileDirectory: URL { cachesDirectory.appendingPathComponent("IIDXChartTraits", isDirectory: true) }
    private var chartDirectory: URL { cachesDirectory.appendingPathComponent("IIDXCharts", isDirectory: true) }

    func profile(for chart: TextageChartViewerChart,
                 difficulty: IIDXLevel,
                 playType: IIDXPlayType) async -> IIDXChartProfile? {
        guard let scoreURL = chart.textageScoreURL(for: difficulty, playType: playType) else { return nil }
        let level = chart.level(for: difficulty, playType: playType)
        let key = [
            String(chart.version), chart.songId,
            playType == .double ? "DP" : "SP", difficulty.code(), String(level)
        ].joined(separator: "_")

        if let profile = profiles[key], profile.isCurrent {
            return profile
        }
        removeLegacyCacheIfNeeded()
        if let profile = read(IIDXChartProfile.self, from: profileDirectory, key: key), profile.isCurrent {
            profiles[key] = profile
            return profile
        }
        if let task = inFlight[key] {
            return await task.value?.0
        }

        let cachedChart = read(IIDXChartData.self, from: chartDirectory, key: key)
        let task = Task.detached { () -> (IIDXChartProfile, IIDXChartData)? in
            var chartData = cachedChart
            if chartData == nil {
                chartData = await Self.fetchChart(scoreURL: scoreURL)
            }
            guard let chartData else { return nil }
            let profile = IIDXChartProfile(notes: chartData.notes, bpmChanges: chartData.bpmChanges,
                                           playType: playType, level: level)
            return (profile, chartData)
        }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        guard let (profile, chartData) = result else { return nil }
        profiles[key] = profile
        write(profile, to: profileDirectory, key: key)
        if cachedChart == nil {
            write(chartData, to: chartDirectory, key: key)
        }
        return profile
    }

    private static func fetchChart(scoreURL: URL) async -> IIDXChartData? {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["url": scoreURL.absoluteString])
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode(ChartResponse.self, from: data) else {
            return nil
        }
        return decoded.data
    }

    private func removeLegacyCacheIfNeeded() {
        guard !hasRemovedLegacyCache else { return }
        hasRemovedLegacyCache = true
        try? FileManager.default.removeItem(at: cachesDirectory.appendingPathComponent("IIDXChartProfiles",
                                                                                       isDirectory: true))
    }

    private func cacheFileURL(in directory: URL, key: String) -> URL {
        directory.appendingPathComponent(key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key)
            .appendingPathExtension("json")
    }

    private func read<Value: Decodable>(_ type: Value.Type, from directory: URL, key: String) -> Value? {
        guard let data = try? Data(contentsOf: cacheFileURL(in: directory, key: key)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func write<Value: Encodable>(_ value: Value, to directory: URL, key: String) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: cacheFileURL(in: directory, key: key), options: .atomic)
    }
}

struct IIDXChartData: Codable, Sendable {
    let notes: [IIDXChartNote]
    let bpmChanges: [IIDXChartBPMChange]
}

private struct ChartResponse: Decodable {
    let data: IIDXChartData
}
