//
//  ProgressAlertManager.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/06/01.
//

import Foundation
import SwiftUI

@Observable
final class ProgressAlertManager: Sendable {
    var isShowing: Bool = false
    var title: String = ""
    var message: String = ""
    var percentage: Int = 0

    @MainActor
    func show(title: String, message: String) {
        withAnimation(.snappy.speed(2.0)) {
            self.title = title
            self.message = message
            percentage = 0
            isShowing = true
        }
    }

    @MainActor
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
