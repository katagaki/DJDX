import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var workoutManager: WatchWorkoutManager

    var body: some View {
        VStack(spacing: 8.0) {
            if workoutManager.isRunning {
                if let startDate = workoutManager.startDate {
                    Text(startDate, style: .timer)
                        .font(.system(.title2, design: .rounded).monospacedDigit())
                }
                HStack(spacing: 6.0) {
                    Image(systemName: "heart.fill").foregroundStyle(.red)
                    Text(verbatim: workoutManager.heartRate > 0 ? "\(workoutManager.heartRate)" : "--")
                        .font(.title3.monospacedDigit())
                }
                HStack(spacing: 6.0) {
                    Image(systemName: "flame.fill").foregroundStyle(.orange)
                    Text(verbatim: "\(workoutManager.activeCalories) kcal")
                        .font(.body.monospacedDigit())
                }
            } else {
                Image(systemName: "figure.dance")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Watch.Idle.Title")
                    .font(.headline)
                Text("Watch.Idle.Message")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}
