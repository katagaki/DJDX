import HealthKit
import SwiftUI
import WatchKit

final class AppDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        Task { @MainActor in
            WatchWorkoutManager.shared.handleRemoteWorkoutLaunch()
        }
    }
}

@main
struct DJDXChargeWatchApp: App {
    @WKApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var workoutManager = WatchWorkoutManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workoutManager)
                .onOpenURL { url in
                    guard url.host == "session" else { return }
                    switch url.lastPathComponent.lowercased() {
                    case "start":
                        workoutManager.requestStartSession()
                    case "stop":
                        workoutManager.requestEndSession()
                    case "pause":
                        if workoutManager.isPaused {
                            workoutManager.resumeWorkout()
                        } else {
                            workoutManager.pauseWorkout()
                        }
                    default:
                        break
                    }
                }
        }
    }
}
