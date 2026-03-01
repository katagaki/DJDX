//
//  QproProvider.swift
//  Widgets
//
//  Created by シン・ジャスティン on 2026/03/01.
//

import SwiftUI
import WidgetKit

struct QproEntry: TimelineEntry {
    let date: Date
    let imageData: Data?
}

struct QproProvider: TimelineProvider {
    func placeholder(in context: Context) -> QproEntry {
        QproEntry(date: .now, imageData: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (QproEntry) -> Void) {
        let imageData = WidgetDataStore.shared.readQproImage()
        completion(QproEntry(date: .now, imageData: imageData))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QproEntry>) -> Void) {
        let imageData = WidgetDataStore.shared.readQproImage()
        let entry = QproEntry(date: .now, imageData: imageData)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 4, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}
