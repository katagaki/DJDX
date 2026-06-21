import SwiftUI
import WidgetKit

struct SessionStartWidget: Widget {
    let kind: String = "SessionStartWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SessionStartProvider()) { _ in
            SessionStartWidgetView()
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Widget.Name.SessionStart")
        .description("Widget.SessionStart.Description")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

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

struct SessionStartWidgetView: View {
    @Environment(\.widgetFamily) private var family

    private static let startURL = URL(string: "djdx://session?action=start")!

    var body: some View {
        content
            .widgetURL(Self.startURL)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Label("Widget.SessionStart.Action", systemImage: "play.fill")
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "play.fill")
                    .font(.title2)
            }
        case .accessoryRectangular:
            HStack(spacing: 8.0) {
                Image(systemName: "figure.dance")
                    .font(.title3)
                Text("Widget.SessionStart.Action")
                    .font(.headline)
                    .lineLimit(1)
            }
        default:
            VStack(spacing: 8.0) {
                Image(systemName: "figure.dance")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                Text("Widget.SessionStart.Action")
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
