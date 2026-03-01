//
//  DJLevelProvider.swift
//  Widgets
//
//  Created by シン・ジャスティン on 2026/03/01.
//

import WidgetKit

struct DJLevelEntry: TimelineEntry {
    let date: Date
    let configuration: DJLevelWidgetIntent
    let dataPerDifficulty: [Int: [String: Int]]?
    let trendData: [String: [Int: [String: Int]]]?
    let playType: String
}

struct DJLevelProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DJLevelEntry {
        DJLevelEntry(date: .now, configuration: DJLevelWidgetIntent(),
                     dataPerDifficulty: nil, trendData: nil, playType: "single")
    }

    func snapshot(for configuration: DJLevelWidgetIntent, in context: Context) async -> DJLevelEntry {
        let snapshot = WidgetDataStore.shared.readDJLevel()
        return DJLevelEntry(
            date: .now, configuration: configuration,
            dataPerDifficulty: snapshot?.dataPerDifficulty,
            trendData: snapshot?.trendData,
            playType: snapshot?.playType ?? "single"
        )
    }

    func timeline(for configuration: DJLevelWidgetIntent,
                  in context: Context) async -> Timeline<DJLevelEntry> {
        let snapshot = WidgetDataStore.shared.readDJLevel()
        let entry = DJLevelEntry(
            date: .now, configuration: configuration,
            dataPerDifficulty: snapshot?.dataPerDifficulty,
            trendData: snapshot?.trendData,
            playType: snapshot?.playType ?? "single"
        )
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 4, to: .now)!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}
