import SwiftUI

@main
struct DJDXChargeWatchApp: App {
    @StateObject private var workoutManager = WatchWorkoutManager()

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
