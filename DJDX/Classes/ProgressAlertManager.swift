//
//  ProgressAlertManager.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/01.
//

import Foundation
import SwiftUI

@Observable
class ProgressAlertManager {
    var isShowing: Bool = false
    var title: String = ""
    var message: String = ""
    var percentage: Int = 0

    func show(title: String, message: String, completion: @escaping () -> Void = {}) {
        withAnimation(.snappy.speed(2.0)) {
            self.title = title
            self.message = message
            percentage = 0
            isShowing = true
        } completion: {
            completion()
        }
    }

    func hide() {
        withAnimation(.snappy.speed(2.0)) {
            isShowing = false
            title = ""
            message = ""
            percentage = 0
        }
    }

    func updateProgress(_ percentage: Int) {
        self.percentage = percentage
    }
}
