import SwiftUI
import WidgetKit

struct QproWidget: Widget {
    let kind: String = "QproWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QproProvider()) { entry in
            QproWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Widget.Name.Qpro")
        .description("Widget.Qpro.Description")
        .supportedFamilies([.systemSmall, .systemLarge])
    }
}

struct QproWidgetView: View {
    let entry: QproEntry

    var body: some View {
        if let imageData = entry.imageData, let uiImage = UIImage(data: imageData) {
            Group {
                Image(uiImage: uiImage)
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .widgetAccentable(false)
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
