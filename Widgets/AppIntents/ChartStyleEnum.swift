//
//  ChartStyleEnum.swift
//  Widgets
//
//  Created by シン・ジャスティン on 2026/03/01.
//

import AppIntents

enum WidgetChartDisplay: String, AppEnum {
    case pie
    case bar
    case trend

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Widget.ChartDisplay.Type"
    static let caseDisplayRepresentations: [WidgetChartDisplay: DisplayRepresentation] = [
        .pie: DisplayRepresentation(title: "Widget.ChartDisplay.Pie"),
        .bar: DisplayRepresentation(title: "Widget.ChartDisplay.Bar"),
        .trend: DisplayRepresentation(title: "Widget.ChartDisplay.Trend")
    ]
}
