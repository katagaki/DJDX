import SwiftUI

@main
struct DJDXChargeWatchApp: App {
    @StateObject private var workoutManager = WatchWorkoutManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workoutManager)
                .onOpenURL { url in
                    if url.host == "start" {
                        workoutManager.requestStartSession()
                    }
                }
        }
    }
}
