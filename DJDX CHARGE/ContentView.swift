import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var workoutManager: WatchWorkoutManager

    var body: some View {
        if workoutManager.isRunning {
            WorkoutView()
        } else {
            ProfileView()
        }
    }
}
