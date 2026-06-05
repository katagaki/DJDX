import Foundation
import SwiftUI

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
        withAnimation {
            isShowing = true
        }
    }

    func hide() {
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
