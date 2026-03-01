//
//  NotesRadarWidgetIntent.swift
//  Widgets
//
//  Created by シン・ジャスティン on 2026/03/01.
//

import AppIntents
import WidgetKit

struct NotesRadarWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Widget.NotesRadar.Name"
    static let description: IntentDescription = "Widget.NotesRadar.Description"

    @Parameter(title: "Widget.NotesRadar.ShowTable", default: true)
    var showTable: Bool
}
