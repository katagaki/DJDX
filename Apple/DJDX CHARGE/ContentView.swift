import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var workoutManager: WatchWorkoutManager

    var body: some View {
        if let issueKey = workoutManager.recordingIssueKey {
            ScrollView {
                VStack(spacing: 12.0) {
                    Text(LocalizedStringKey(issueKey))
                    if !workoutManager.isRunning {
                        Button("Watch.Recording.Retry") { workoutManager.retryWorkout() }
                        Button("Watch.Shared.Cancel") { workoutManager.dismissRecordingIssue() }
                    }
                }
                .padding()
            }
        } else if workoutManager.isRunning {
            WorkoutView()
        } else {
            ProfileView()
        }
    }
}
