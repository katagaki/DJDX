import UIKit

@MainActor
final class IIDXSessionBackgroundActivity {
    static let shared = IIDXSessionBackgroundActivity()

    private var taskID: UIBackgroundTaskIdentifier = .invalid
    private var count = 0

    func begin() {
        count += 1
        guard taskID == .invalid else { return }
        taskID = UIApplication.shared.beginBackgroundTask(withName: "SessionOCR") { [weak self] in
            self?.endNow()
        }
    }

    func end() {
        count = max(0, count - 1)
        if count == 0 { endNow() }
    }

    private func endNow() {
        guard taskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(taskID)
        taskID = .invalid
        count = 0
    }
}
