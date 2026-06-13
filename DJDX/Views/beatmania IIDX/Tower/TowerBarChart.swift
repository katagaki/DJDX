import Charts
import SwiftUI

struct TowerBarChart: View {
    let entries: [IIDXTowerEntry]
    var usesDateAxis: Bool = true

    var body: some View {
        Group {
            if usesDateAxis {
                Chart(entries, id: \.playDate) { entry in
                    BarMark(
                        x: .value("Tower.Header.PlayDate",
                                  entry.playDate, unit: .day),
                        y: .value("Shared.IIDX.Keys", entry.keyCount)
                    )
                    .foregroundStyle(.blue)
                    .position(by: .value("Tower.Type", "Keys"))

                    BarMark(
                        x: .value("Tower.Header.PlayDate",
                                  entry.playDate, unit: .day),
                        y: .value("Shared.IIDX.Scratch", entry.scratchCount)
                    )
                    .foregroundStyle(.red)
                    .position(by: .value("Tower.Type", "Scratch"))
                }
            } else {
                Chart(Array(entries.enumerated()), id: \.element.playDate) { index, entry in
                    BarMark(
                        x: .value("Tower.Header.PlayDate", index),
                        y: .value("Shared.IIDX.Keys", entry.keyCount)
                    )
                    .foregroundStyle(.blue)
                    .position(by: .value("Tower.Type", "Keys"))

                    BarMark(
                        x: .value("Tower.Header.PlayDate", index),
                        y: .value("Shared.IIDX.Scratch", entry.scratchCount)
                    )
                    .foregroundStyle(.red)
                    .position(by: .value("Tower.Type", "Scratch"))
                }
            }
        }
        .chartXScale(range: .plotDimension(startPadding: 8.0, endPadding: 8.0))
    }
}
