//
//  ImportMovedTip.swift
//  DJDX
//
//  Created by Claude on 2026/05/29.
//

import Foundation
import TipKit

struct ImportMovedTip: Tip {
    var title: Text {
        Text("Tips.ImportMoved.Title")
    }
    var message: Text? {
        Text("Tips.ImportMoved.Text")
    }
    var image: Image? {
        Image(systemName: "arrow.down.circle.dotted")
    }
}
