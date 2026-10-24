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
    var isIndeterminate: Bool = false

    func show(title: String, message: String, isIndeterminate: Bool = false) {
        self.title = title
        self.message = message
        self.isIndeterminate = isIndeterminate
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
        }
    }

    func updateProgress(_ percentage: Int) {
        self.percentage = percentage
    }

    func updateTitle(_ title: LocalizedStringResource) {
        self.title = String(localized: title)
    }
}
