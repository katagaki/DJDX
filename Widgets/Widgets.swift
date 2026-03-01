//
//  Widgets.swift
//  Widgets
//
//  Created by シン・ジャスティン on 2026/03/01.
//

import SwiftUI
import WidgetKit

@main
struct DJDXWidgetBundle: WidgetBundle {
    var body: some Widget {
        QproWidget()
        NotesRadarWidget()
        ClearTypeWidget()
        DJLevelWidget()
        TowerWidget()
    }
}
