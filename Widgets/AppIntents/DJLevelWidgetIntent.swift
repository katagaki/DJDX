//
//  DJLevelWidgetIntent.swift
//  Widgets
//
//  Created by シン・ジャスティン on 2026/03/01.
//

import AppIntents
import WidgetKit

struct DJLevelWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Widget.DJLevel.Name"
    static let description: IntentDescription = "Widget.DJLevel.Description"

    @Parameter(title: "Widget.ChartDisplay.Type", default: .bar)
    var chartDisplay: WidgetChartDisplay
}
