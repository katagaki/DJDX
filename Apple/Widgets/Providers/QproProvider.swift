import SwiftUI
import WidgetKit

struct QproEntry: TimelineEntry {
    let date: Date
    let imageData: Data?
}

struct QproProvider: TimelineProvider {
    func placeholder(in _: Context) -> QproEntry {
        QproEntry(date: .now, imageData: nil)
    }

    func getSnapshot(in _: Context, completion: @escaping (QproEntry) -> Void) {
        let imageData = try? Data(contentsOf: SharedContainer.imagesURL.appendingPathComponent("Qpro.png"))
        completion(QproEntry(date: .now, imageData: imageData))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<QproEntry>) -> Void) {
        let imageData = try? Data(contentsOf: SharedContainer.imagesURL.appendingPathComponent("Qpro.png"))
        let entry = QproEntry(date: .now, imageData: imageData)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 4, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}
