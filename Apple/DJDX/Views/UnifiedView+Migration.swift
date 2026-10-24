import SwiftUI
import UIKit

extension UnifiedView {
#if DEBUG
    func runFakeMigration() async {
        migrationProgress.show(
            title: "Migration.Title",
            message: "Migration.Description"
        )
        let steps = 30
        for step in 1...steps {
            try? await Task.sleep(for: .milliseconds(3000 / steps))
            migrationProgress.updateProgress((step * 100) / steps)
        }
        migrationProgress.hide()
    }
#endif

}
