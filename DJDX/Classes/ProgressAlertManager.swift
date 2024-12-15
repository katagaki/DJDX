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
        self.title = title
        self.message = message
        percentage = 0
        isShowing = true
        completion()
    }

    func hide() {
        isShowing = false
        title = ""
        message = ""
        percentage = 0
    }

    @MainActor
    func updateProgress(_ percentage: Int) {
        self.percentage = percentage
    }

    @MainActor
    func updateTitle(_ title: LocalizedStringResource) {
        self.title = String(localized: title)
    }
}
