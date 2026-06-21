import SwiftUI

struct WorkoutView: View {
    @EnvironmentObject private var workoutManager: WatchWorkoutManager

    var body: some View {
        ScrollView {
            VStack(spacing: 10.0) {
                if let startDate = workoutManager.startDate {
                    Text(startDate, style: .timer)
                        .font(.system(size: 40.0, weight: .semibold, design: .rounded).monospacedDigit())
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }

                HStack(spacing: 14.0) {
                    HStack(spacing: 4.0) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                            .heartbeat(isActive: workoutManager.heartRate > 0)
                        Text(verbatim: workoutManager.heartRate > 0 ? "\(workoutManager.heartRate)" : "--")
                            .font(.body.monospacedDigit())
                    }
                    HStack(spacing: 4.0) {
                        Image(systemName: "flame.fill").foregroundStyle(.orange)
                        Text(verbatim: "\(workoutManager.activeCalories)")
                            .font(.body.monospacedDigit())
                    }
                }

                Divider()

                VStack(spacing: 2.0) {
                    Text(verbatim: "\(workoutManager.playCount)")
                        .font(.system(.title, design: .rounded).weight(.bold).monospacedDigit())
                    Text("Watch.Session.Plays")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let lastSongTitle = workoutManager.lastSongTitle {
                    WatchSessionResultLabel(
                        title: lastSongTitle,
                        rank: workoutManager.lastDJLevel,
                        clearType: workoutManager.lastClearType,
                        score: workoutManager.lastScore,
                        fallbackSummary: workoutManager.lastResultSummary
                    )
                }

                if let best = workoutManager.bestThisSession {
                    HStack(spacing: 4.0) {
                        Image(systemName: "trophy.fill").foregroundStyle(.yellow)
                        Text("Watch.Session.Best")
                            .foregroundStyle(.secondary)
                        Text(verbatim: best).fontWeight(.semibold)
                    }
                    .font(.caption2)
                }
            }
            .padding()
        }
    }
}
