//
//  TowerWidgetView.swift
//  Widgets
//
//  Created by シン・ジャスティン on 2026/03/01.
//

import SwiftUI
import WidgetKit

struct TowerWidget: Widget {
    let kind: String = "TowerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TowerProvider()) { entry in
            TowerWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Shared.IIDX.Tower")
        .description("Widget.Tower.Description")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct TowerWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: TowerEntry

    var body: some View {
        if let data = entry.towerData {
            switch family {
            case .systemSmall:
                WidgetTowerChart(
                    totalKeyCount: data.totalKeyCount,
                    totalScratchCount: data.totalScratchCount
                )
            case .systemMedium:
                HStack {
                    WidgetTowerChart(
                        totalKeyCount: data.totalKeyCount,
                        totalScratchCount: data.totalScratchCount
                    )
                    towerNumbers(data)
                }
            case .systemLarge:
                VStack(spacing: 8.0) {
                    WidgetTowerChart(
                        totalKeyCount: data.totalKeyCount,
                        totalScratchCount: data.totalScratchCount
                    )
                    recentEntries(data.latestEntries)
                        .padding(.horizontal, 8.0)
                }
            default:
                WidgetTowerChart(
                    totalKeyCount: data.totalKeyCount,
                    totalScratchCount: data.totalScratchCount
                )
            }
        } else {
            VStack(spacing: 8.0) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Shared.IIDX.NoData")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    func towerNumbers(_ data: WidgetTowerSnapshot) -> some View {
        let keyHeight = Int(Double(data.totalKeyCount) / 7.0)
        let scratchHeight = data.totalScratchCount
        VStack(alignment: .leading, spacing: 8.0) {
            Spacer()
            VStack(alignment: .leading, spacing: 2.0) {
                Text("Shared.IIDX.Keys")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(verbatim: "\(keyHeight)m")
                    .font(.body.monospacedDigit())
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
            }
            VStack(alignment: .leading, spacing: 2.0) {
                Text("Shared.IIDX.Scratch")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(verbatim: "\(scratchHeight)m")
                    .font(.body.monospacedDigit())
                    .fontWeight(.bold)
                    .foregroundStyle(.red)
            }
            Spacer()
        }
        .padding(.trailing, 8.0)
    }

    @ViewBuilder
    func recentEntries(_ entries: [WidgetTowerEntry]) -> some View {
        if entries.isEmpty {
            Text("Shared.IIDX.NoEntries")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 4.0) {
                HStack {
                    Text("Tower.Header.PlayDate")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Shared.IIDX.Keys")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .trailing)
                    Text("Shared.IIDX.Scratch")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .trailing)
                }
                ForEach(entries, id: \.playDate) { entry in
                    HStack {
                        Text(entry.playDate, format: .dateTime.month().day())
                            .font(.system(size: 11).monospacedDigit())
                        Spacer()
                        Text(verbatim: "\(entry.keyCount)")
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(.blue)
                            .frame(width: 60, alignment: .trailing)
                        Text(verbatim: "\(entry.scratchCount)")
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(.red)
                            .frame(width: 60, alignment: .trailing)
                    }
                }
            }
        }
    }
}
