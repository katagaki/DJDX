//
//  ClearTypeProvider.swift
//  Widgets
//
//  Created by シン・ジャスティン on 2026/03/01.
//

import WidgetKit

struct ClearTypeEntry: TimelineEntry {
    let date: Date
    let configuration: ClearTypeWidgetIntent
    let dataPerDifficulty: [Int: [String: Int]]?
    let trendData: [String: [Int: [String: Int]]]?
    let playType: String
}

struct ClearTypeProvider: AppIntentTimelineProvider {
    func placeholder(in _: Context) -> ClearTypeEntry {
        ClearTypeEntry(date: .now, configuration: ClearTypeWidgetIntent(),
                       dataPerDifficulty: nil, trendData: nil, playType: "single")
    }

    func snapshot(for configuration: ClearTypeWidgetIntent, in _: Context) async -> ClearTypeEntry {
        let snapshot = WidgetDataStore.shared.readClearType()
        return ClearTypeEntry(
            date: .now, configuration: configuration,
            dataPerDifficulty: snapshot?.dataPerDifficulty,
            trendData: snapshot?.trendData,
            playType: snapshot?.playType ?? "single"
        )
    }

    func timeline(for configuration: ClearTypeWidgetIntent,
                  in _: Context) async -> Timeline<ClearTypeEntry> {
        let snapshot = WidgetDataStore.shared.readClearType()
        let entry = ClearTypeEntry(
            date: .now, configuration: configuration,
            dataPerDifficulty: snapshot?.dataPerDifficulty,
            trendData: snapshot?.trendData,
            playType: snapshot?.playType ?? "single"
        )
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 4, to: .now)!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}
