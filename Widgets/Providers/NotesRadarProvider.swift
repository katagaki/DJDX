//
//  NotesRadarProvider.swift
//  Widgets
//
//  Created by シン・ジャスティン on 2026/03/01.
//

import WidgetKit

struct NotesRadarEntry: TimelineEntry {
    let date: Date
    let configuration: NotesRadarWidgetIntent
    let radarData: WidgetRadarData?
}

struct NotesRadarProvider: AppIntentTimelineProvider {
    func placeholder(in _: Context) -> NotesRadarEntry {
        NotesRadarEntry(date: .now, configuration: NotesRadarWidgetIntent(), radarData: nil)
    }

    func snapshot(for configuration: NotesRadarWidgetIntent, in _: Context) async -> NotesRadarEntry {
        let snapshot = WidgetDataStore.shared.readRadar()
        return NotesRadarEntry(
            date: .now, configuration: configuration,
            radarData: snapshot?.spData
        )
    }

    func timeline(for configuration: NotesRadarWidgetIntent,
                  in _: Context) async -> Timeline<NotesRadarEntry> {
        let snapshot = WidgetDataStore.shared.readRadar()
        let entry = NotesRadarEntry(
            date: .now, configuration: configuration,
            radarData: snapshot?.spData
        )
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 4, to: .now)!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}
