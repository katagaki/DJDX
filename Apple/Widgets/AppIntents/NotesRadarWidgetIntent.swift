import AppIntents
import WidgetKit

struct NotesRadarWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Shared.IIDX.NotesRadar"
    static let description: IntentDescription = "Widget.NotesRadar.Description"

    @Parameter(title: "Widget.NotesRadar.ShowTable", default: true)
    var showTable: Bool
}
