import SwiftUI
import WidgetKit

struct SessionStartEntry: TimelineEntry {
    let date: Date
    var radarSP: [Double]?
    var radarDP: [Double]?

    var radar: [Double]? { radarSP ?? radarDP }
}

struct SessionStartProvider: TimelineProvider {
    func placeholder(in context: Context) -> SessionStartEntry {
        SessionStartEntry(date: Date(timeIntervalSince1970: 0))
    }

    func getSnapshot(in context: Context, completion: @escaping (SessionStartEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SessionStartEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func currentEntry() -> SessionStartEntry {
        let defaults = UserDefaults(suiteName: "group.com.tsubuzaki.DJDX")
        return SessionStartEntry(
            date: Date(timeIntervalSince1970: 0),
            radarSP: radar(defaults, "Watch.Complication.RadarSP"),
            radarDP: radar(defaults, "Watch.Complication.RadarDP")
        )
    }

    private func radar(_ defaults: UserDefaults?, _ key: String) -> [Double]? {
        guard let raw = defaults?.array(forKey: key) else { return nil }
        let values = raw.compactMap { ($0 as? NSNumber)?.doubleValue }
        return values.count == 6 && values.contains(where: { $0 > 0 }) ? values : nil
    }
}

struct SessionStartComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SessionStartEntry

    private static let startURL = URL(string: "djdx://session/start")!

    var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Label("Watch.Widget.Start", systemImage: "play.fill")
                .widgetURL(Self.startURL)
        case .accessoryCorner:
            Image(systemName: "play.fill")
                .font(.title3)
                .foregroundStyle(.accent)
                .widgetLabel("Watch.Widget.Start")
                .widgetURL(Self.startURL)
        case .accessoryRectangular:
            if let values = entry.radar {
                radarContent(values)
            } else {
                startContent
                    .widgetURL(Self.startURL)
            }
        default:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "play.fill")
                    .font(.title2)
                    .foregroundStyle(.accent)
            }
            .widgetURL(Self.startURL)
        }
    }

    private var startContent: some View {
        HStack(spacing: 6.0) {
            Image(systemName: "figure.walk")
                .font(.title3)
                .foregroundStyle(.accent)
            Text("Watch.Widget.StartSession")
                .font(.headline)
                .lineLimit(1)
        }
    }

    private static let radarLabels = ["NOTES", "CHORD", "PEAK", "CHARGE", "SCRATCH", "SOF-LAN"]
    private static let radarColors: [Color] = [
        .init(red: 1.0, green: 64 / 255, blue: 235 / 255),
        .init(red: 133 / 255, green: 225 / 255, blue: 0 / 255),
        .init(red: 1.0, green: 108 / 255, blue: 0 / 255),
        .init(red: 137 / 255, green: 87 / 255, blue: 221 / 255),
        .init(red: 221 / 255, green: 0 / 255, blue: 0 / 255),
        .init(red: 0 / 255, green: 134 / 255, blue: 229 / 255)
    ]

    private func radarContent(_ values: [Double]) -> some View {
        HStack(spacing: 6.0) {
            ComplicationRadarView(values: values)
                .aspectRatio(1.0, contentMode: .fit)
            VStack(spacing: 0.0) {
                ForEach(Array(Self.radarLabels.enumerated()), id: \.offset) { index, label in
                    HStack(spacing: 2.0) {
                        Text(verbatim: label)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Self.radarColors[index])
                        Spacer(minLength: 2.0)
                        Text(verbatim: String(format: "%.2f", index < values.count ? values[index] : 0))
                            .font(.system(size: 9, weight: .semibold).monospacedDigit())
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                }
            }
        }
    }
}

struct SessionStartComplication: Widget {
    let kind: String = "SessionStartComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SessionStartProvider()) { entry in
            SessionStartComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Watch.Widget.Name")
        .description("Watch.Widget.Description")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}
