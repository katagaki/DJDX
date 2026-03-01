//
//  QproWidgetView.swift
//  Widgets
//
//  Created by シン・ジャスティン on 2026/03/01.
//

import SwiftUI
import WidgetKit

struct QproWidget: Widget {
    let kind: String = "QproWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QproProvider()) { entry in
            QproWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Widget.Qpro.Name")
        .description("Widget.Qpro.Description")
        .supportedFamilies([.systemSmall, .systemLarge])
    }
}

struct QproWidgetView: View {
    let entry: QproEntry

    var body: some View {
        if let imageData = entry.imageData, let uiImage = UIImage(data: imageData) {
            Group {
                if #available(iOS 18.0, *) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .widgetAccentedRenderingMode(.fullColor)
                        .widgetAccentable(false)
                } else {
                    Image(uiImage: uiImage)
                        .resizable()
                }
            }
            .scaledToFit()
        } else {
            VStack(spacing: 8.0) {
                Image(systemName: "person.crop.square")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Widget.Qpro.NotLoaded")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
