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
        let snapshot = WidgetDataReader.shared.tower()
        completion(TowerEntry(date: .now, towerData: snapshot))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<TowerEntry>) -> Void) {
        let snapshot = WidgetDataReader.shared.tower()
        let entry = TowerEntry(date: .now, towerData: snapshot)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 4, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}
