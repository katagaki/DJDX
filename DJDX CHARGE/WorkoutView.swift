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
                        Image(systemName: "heart.fill").foregroundStyle(.red)
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
                    VStack(spacing: 1.0) {
                        Text(verbatim: lastSongTitle)
                            .font(.footnote.weight(.semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        if let summary = workoutManager.lastResultSummary {
                            Text(verbatim: summary)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity)
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
