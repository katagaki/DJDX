import Charts
import SwiftUI

struct TowerTotalsChart: View {
    let totalKeyCount: Int
    let totalScratchCount: Int
    var showsAnnotations: Bool = true

    /// 鍵盤タワー: 鍵盤7回分で1cm
    var keyTowerHeight: Double {
        Double(totalKeyCount) / 7.0
    }

    /// スクラッチタワー: スクラッチ1回分で1cm
    var scratchTowerHeight: Double {
        Double(totalScratchCount)
    }

    // Leave headroom above the tallest bar so the meter annotation isn't clipped.
    var yUpperBound: Double {
        max(keyTowerHeight, scratchTowerHeight, 1.0) * 1.2
    }

    var body: some View {
        Chart {
            BarMark(
                x: .value("Tower.Type",
                          NSLocalizedString("Tower.Totals.Keys", comment: "")),
                y: .value("Tower.Totals.Height", keyTowerHeight)
            )
            .foregroundStyle(.blue)
            .annotation(position: .top) {
                if showsAnnotations {
                    Text("Tower.Totals.HeightValue.\(Int(keyTowerHeight))")
                        .font(.caption)
                        .monospacedDigit()
                }
            }

            BarMark(
                x: .value("Tower.Type",
                          NSLocalizedString("Tower.Totals.Scratch", comment: "")),
                y: .value("Tower.Totals.Height", scratchTowerHeight)
            )
            .foregroundStyle(.red)
            .annotation(position: .top) {
                if showsAnnotations {
                    Text("Tower.Totals.HeightValue.\(Int(scratchTowerHeight))")
                        .font(.caption)
                        .monospacedDigit()
                }
            }
        }
        .chartXScale(range: .plotDimension(startPadding: 16.0, endPadding: 16.0))
        .chartYScale(domain: 0.0...yUpperBound)
    }
}
