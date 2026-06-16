import Foundation
import SwiftUI
import UIKit

@Observable
@MainActor
final class ProgressReporter {
    var isShowing: Bool = false
    var title: String = ""
    var message: String = ""
    var percentage: Int = 0

    func show(title: String, message: String) {
        self.title = title
        self.message = message
        percentage = 0
        UIApplication.shared.isIdleTimerDisabled = true
        withAnimation {
            isShowing = true
        }
    }

    func hide() {
        UIApplication.shared.isIdleTimerDisabled = false
        withAnimation {
            isShowing = false
        } completion: {
            self.title = ""
            self.message = ""
            self.percentage = 0
        }
    }

    func updateProgress(_ percentage: Int) {
        self.percentage = percentage
    }

    func updateTitle(_ title: LocalizedStringResource) {
        self.title = String(localized: title)
    }
}
