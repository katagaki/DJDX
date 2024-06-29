//
//  StartHereTip.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/29.
//

import Foundation
import TipKit

struct StartHereTip: Tip {
    var title: Text {
        Text("Tips.StartHere.Title")
    }
    var message: Text? {
        Text("Tips.StartHere.Text")
    }
    var image: Image? {
        Image(systemName: "hand.wave")
    }
}
