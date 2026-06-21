import SwiftUI

struct WorkoutView: View {
    @EnvironmentObject private var workoutManager: WatchWorkoutManager
    @State private var isConfirmingStop: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10.0) {
                if let startDate = workoutManager.startDate {
                    Group {
                        if workoutManager.isPaused {
                            Text(verbatim: elapsedString(workoutManager.pausedElapsed))
                        } else {
                            Text(startDate, style: .timer)
                        }
                    }
                    .font(.system(size: 40.0, weight: .semibold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    if workoutManager.isPaused {
                        Label("Watch.Session.Paused", systemImage: "pause.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
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

                if workoutManager.isCollecting {
                    pauseButton
                        .padding(.top, 6.0)
                }
                stopButton
                    .padding(.top, 6.0)
            }
            .padding()
        }
        .confirmationDialog(
            "Watch.Session.Stop.Confirm",
            isPresented: $isConfirmingStop,
            titleVisibility: .visible
        ) {
            Button("Watch.Session.Stop", role: .destructive) {
                workoutManager.requestEndSession()
            }
            Button("Watch.Shared.Cancel", role: .cancel) {}
        }
    }

    private func elapsedString(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    @ViewBuilder
    private var pauseButton: some View {
        let button = Button {
            if workoutManager.isPaused {
                workoutManager.resumeWorkout()
            } else {
                workoutManager.pauseWorkout()
            }
        } label: {
            Label(
                workoutManager.isPaused ? "Watch.Session.Resume" : "Watch.Session.Pause",
                systemImage: workoutManager.isPaused ? "play.fill" : "pause.fill"
            )
            .frame(maxWidth: .infinity)
        }
        .tint(workoutManager.isPaused ? .green : .orange)
        if #available(watchOS 26.0, *) {
            button.buttonStyle(.glass)
        } else {
            button.buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var stopButton: some View {
        let button = Button(role: .destructive) {
            isConfirmingStop = true
        } label: {
            Label("Watch.Session.Stop", systemImage: "stop.fill")
                .frame(maxWidth: .infinity)
        }
        .tint(.red)
        if #available(watchOS 26.0, *) {
            button.buttonStyle(.glass)
        } else {
            button.buttonStyle(.bordered)
        }
    }
}
