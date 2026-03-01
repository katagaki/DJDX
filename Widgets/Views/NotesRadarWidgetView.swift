//
//  NotesRadarWidgetView.swift
//  Widgets
//
//  Created by シン・ジャスティン on 2026/03/01.
//

import SwiftUI
import WidgetKit

struct NotesRadarWidget: Widget {
    let kind: String = "NotesRadarWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: NotesRadarWidgetIntent.self,
                               provider: NotesRadarProvider()) { entry in
            NotesRadarWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Widget.NotesRadar.Name")
        .description("Widget.NotesRadar.Description")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct NotesRadarWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: NotesRadarEntry

    var body: some View {
        if let data = entry.radarData {
            switch family {
            case .systemSmall:
                WidgetRadarChartView(data: data, showLabels: true, labelFontSize: 6)
                    .padding(8.0)
            case .systemMedium:
                HStack(spacing: 8.0) {
                    if entry.configuration.showTable {
                        WidgetRadarChartView(data: data, showLabels: true, labelFontSize: 6)
                        Divider()
                        radarTable(data: data)
                            .frame(width: 120.0)
                            .padding(.trailing, 4.0)
                    } else {
                        WidgetRadarChartView(data: data, showLabels: true, labelFontSize: 6)
                    }
                }
            case .systemLarge:
                VStack(spacing: 8.0) {
                    if entry.configuration.showTable {
                        WidgetRadarChartView(data: data, showLabels: true, labelFontSize: 10)
                        Divider()
                        radarTable(data: data)
                    } else {
                        WidgetRadarChartView(data: data, showLabels: true, labelFontSize: 10)
                            .padding(32.0)
                    }
                }
            default:
                WidgetRadarChartView(data: data)
            }
        } else {
            VStack(spacing: 8.0) {
                Image(systemName: "chart.dots.scatter")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Widget.NotesRadar.NoData")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private static let displayOrder = ["NOTES", "CHORD", "PEAK", "CHARGE", "SCRATCH", "SOF-LAN"]
    private static let displayColors: [String: Color] = [
        "NOTES": .init(red: 1.0, green: 64 / 255, blue: 235 / 255),
        "CHORD": .init(red: 133 / 255, green: 225 / 255, blue: 0 / 255),
        "PEAK": .init(red: 1.0, green: 108 / 255, blue: 0 / 255),
        "CHARGE": .init(red: 137 / 255, green: 87 / 255, blue: 221 / 255),
        "SCRATCH": .init(red: 221 / 255, green: 0 / 255, blue: 0 / 255),
        "SOF-LAN": .init(red: 0 / 255, green: 134 / 255, blue: 229 / 255)
    ]

    private func value(for label: String) -> Double {
        guard let data = entry.radarData else { return 0 }
        switch label {
        case "NOTES": return data.notes
        case "CHORD": return data.chord
        case "PEAK": return data.peak
        case "CHARGE": return data.charge
        case "SCRATCH": return data.scratch
        case "SOF-LAN": return data.soflan
        default: return 0
        }
    }

    @ViewBuilder
    func radarTable(data: WidgetRadarData) -> some View {
        VStack(spacing: 2.0) {
            ForEach(Self.displayOrder, id: \.self) { label in
                HStack {
                    Text(verbatim: label)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Self.displayColors[label] ?? .primary)
                    Spacer()
                    Text(verbatim: String(format: "%.2f", value(for: label)))
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                }
            }
            Divider()
            HStack {
                Text(verbatim: "TOTAL")
                    .font(.system(size: 10, weight: .bold))
                Spacer()
                Text(verbatim: String(format: "%.2f", data.sum))
                    .font(.system(size: 10, weight: .bold).monospacedDigit())
            }
        }
    }
}
