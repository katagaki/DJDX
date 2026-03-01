//
//  WidgetLevelEnum.swift
//  Widgets
//
//  Created by シン・ジャスティン on 2026/03/01.
//

import AppIntents

enum WidgetLevel: Int, AppEnum, CaseIterable {
    case level1 = 1
    case level2 = 2
    case level3 = 3
    case level4 = 4
    case level5 = 5
    case level6 = 6
    case level7 = 7
    case level8 = 8
    case level9 = 9
    case level10 = 10
    case level11 = 11
    case level12 = 12

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Widget.Level.Type"
    static let caseDisplayRepresentations: [WidgetLevel: DisplayRepresentation] = [
        .level1: DisplayRepresentation(title: "LEVEL 1"),
        .level2: DisplayRepresentation(title: "LEVEL 2"),
        .level3: DisplayRepresentation(title: "LEVEL 3"),
        .level4: DisplayRepresentation(title: "LEVEL 4"),
        .level5: DisplayRepresentation(title: "LEVEL 5"),
        .level6: DisplayRepresentation(title: "LEVEL 6"),
        .level7: DisplayRepresentation(title: "LEVEL 7"),
        .level8: DisplayRepresentation(title: "LEVEL 8"),
        .level9: DisplayRepresentation(title: "LEVEL 9"),
        .level10: DisplayRepresentation(title: "LEVEL 10"),
        .level11: DisplayRepresentation(title: "LEVEL 11"),
        .level12: DisplayRepresentation(title: "LEVEL 12")
    ]
}
