//
//  ClearTypeWidgetIntent.swift
//  Widgets
//
//  Created by シン・ジャスティン on 2026/03/01.
//

import AppIntents
import WidgetKit

struct ClearTypeWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Widget.ClearType.Name"
    static let description: IntentDescription = "Widget.ClearType.Description"

    @Parameter(title: "Widget.ChartDisplay.Type", default: .pie)
    var chartDisplay: WidgetChartDisplay
}
