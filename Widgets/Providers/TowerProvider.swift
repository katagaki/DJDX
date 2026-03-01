//
//  TowerProvider.swift
//  Widgets
//
//  Created by シン・ジャスティン on 2026/03/01.
//

import WidgetKit

struct TowerEntry: TimelineEntry {
    let date: Date
    let towerData: WidgetTowerSnapshot?
}

struct TowerProvider: TimelineProvider {
    func placeholder(in _: Context) -> TowerEntry {
        TowerEntry(date: .now, towerData: nil)
    }

    func getSnapshot(in _: Context, completion: @escaping (TowerEntry) -> Void) {
        let snapshot = WidgetDataStore.shared.readTower()
        completion(TowerEntry(date: .now, towerData: snapshot))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<TowerEntry>) -> Void) {
        let snapshot = WidgetDataStore.shared.readTower()
        let entry = TowerEntry(date: .now, towerData: snapshot)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 4, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}
