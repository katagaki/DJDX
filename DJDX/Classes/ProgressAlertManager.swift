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
        // HACK: Using withAnimation here somehow causes the app to freeze. WTF?
        self.title = title
        self.message = message
        percentage = 0
        isShowing = true
        completion()
    }

    func hide() {
        // HACK: Using withAnimation here somehow causes the app to freeze. WTF?
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
