import SwiftUI

@main
struct DJDXChargeWatchApp: App {
    @StateObject private var workoutManager = WatchWorkoutManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workoutManager)
        }
    }
}
