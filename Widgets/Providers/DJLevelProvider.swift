import WidgetKit

struct DJLevelEntry: TimelineEntry {
    let date: Date
    let configuration: DJLevelWidgetIntent
    let dataPerDifficulty: [Int: [String: Int]]?
    let trendData: [String: [Int: [String: Int]]]?
    let playType: String
}

struct DJLevelProvider: AppIntentTimelineProvider {
    func placeholder(in _: Context) -> DJLevelEntry {
        DJLevelEntry(date: .now, configuration: DJLevelWidgetIntent(),
                     dataPerDifficulty: nil, trendData: nil, playType: "single")
    }

    func snapshot(for configuration: DJLevelWidgetIntent, in _: Context) async -> DJLevelEntry {
        let snapshot = WidgetDataReader.shared.djLevel(
            versionRaw: WidgetConfig.iidxVersionRaw,
            playTypeRaw: WidgetConfig.playTypeRaw
        )
        return DJLevelEntry(
            date: .now, configuration: configuration,
            dataPerDifficulty: snapshot.dataPerDifficulty,
            trendData: snapshot.trendData,
            playType: snapshot.playType
        )
    }

    func timeline(for configuration: DJLevelWidgetIntent,
                  in _: Context) async -> Timeline<DJLevelEntry> {
        let snapshot = WidgetDataReader.shared.djLevel(
            versionRaw: WidgetConfig.iidxVersionRaw,
            playTypeRaw: WidgetConfig.playTypeRaw
        )
        let entry = DJLevelEntry(
            date: .now, configuration: configuration,
            dataPerDifficulty: snapshot.dataPerDifficulty,
            trendData: snapshot.trendData,
            playType: snapshot.playType
        )
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 4, to: .now)!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}
