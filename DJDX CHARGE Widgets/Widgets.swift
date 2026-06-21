import SwiftUI
import WidgetKit

struct SessionStartEntry: TimelineEntry {
    let date: Date
}

struct SessionStartProvider: TimelineProvider {
    func placeholder(in context: Context) -> SessionStartEntry {
        SessionStartEntry(date: Date(timeIntervalSince1970: 0))
    }

    func getSnapshot(in context: Context, completion: @escaping (SessionStartEntry) -> Void) {
        completion(SessionStartEntry(date: Date(timeIntervalSince1970: 0)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SessionStartEntry>) -> Void) {
        completion(Timeline(entries: [SessionStartEntry(date: Date(timeIntervalSince1970: 0))], policy: .never))
    }
}

struct SessionStartComplicationView: View {
    @Environment(\.widgetFamily) private var family

    private static let startURL = URL(string: "djdx://session/start")!

    var body: some View {
        content
            .widgetURL(Self.startURL)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Label("Watch.Widget.Start", systemImage: "play.fill")
        case .accessoryCorner:
            Image(systemName: "play.fill")
                .font(.title3)
                .widgetLabel("Watch.Widget.Start")
        case .accessoryRectangular:
            HStack(spacing: 6.0) {
                Image(systemName: "figure.dance")
                    .font(.title3)
                Text("Watch.Widget.StartSession")
                    .font(.headline)
                    .lineLimit(1)
            }
        default:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "play.fill")
                    .font(.title2)
            }
        }
    }
}

struct SessionStartComplication: Widget {
    let kind: String = "SessionStartComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SessionStartProvider()) { _ in
            SessionStartComplicationView()
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Watch.Widget.Name")
        .description("Watch.Widget.Description")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}
