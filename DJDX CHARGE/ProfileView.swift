import SwiftUI
import UIKit

private enum WatchPlayType: String {
    case sp
    case dp

    var label: String {
        switch self {
        case .sp: return "SP"
        case .dp: return "DP"
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject private var workoutManager: WatchWorkoutManager
    @AppStorage("Watch.Profile.PlayType") private var playTypeRaw = WatchPlayType.sp.rawValue

    private var hasProfile: Bool {
        workoutManager.qproImageData != nil
            || workoutManager.djName != nil
            || workoutManager.spRadar != nil
            || workoutManager.dpRadar != nil
    }

    private var bothRadars: Bool {
        workoutManager.spRadar != nil && workoutManager.dpRadar != nil
    }

    private var effectiveType: WatchPlayType {
        let desired = WatchPlayType(rawValue: playTypeRaw) ?? .sp
        switch desired {
        case .sp: return workoutManager.spRadar != nil ? .sp : (workoutManager.dpRadar != nil ? .dp : .sp)
        case .dp: return workoutManager.dpRadar != nil ? .dp : (workoutManager.spRadar != nil ? .sp : .dp)
        }
    }

    private var selectedRadar: WatchRadarData? {
        effectiveType == .sp ? workoutManager.spRadar : workoutManager.dpRadar
    }

    private var selectedRank: String? {
        let rank = effectiveType == .sp ? workoutManager.spRank : workoutManager.dpRank
        guard let rank, rank != "--" else { return nil }
        return rank
    }

    var body: some View {
        NavigationStack {
            content
                .toolbar {
                    if bothRadars {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(action: togglePlayType) {
                                Text(verbatim: effectiveType.label)
                                    .font(.caption2.weight(.bold))
                            }
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if hasProfile {
            ScrollView {
                VStack(spacing: 12.0) {
                    startButton
                    profileHeader
                    if let radar = selectedRadar {
                        WatchRadarChartView(data: radar)
                            .aspectRatio(1.0, contentMode: .fit)
                        WatchRadarTableView(data: radar)
                    }
                }
                .padding()
            }
        } else {
            idlePlaceholder
        }
    }

    private var startButton: some View {
        Button {
            workoutManager.requestStartSession()
        } label: {
            Label("Watch.Session.Start", systemImage: "play.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.accentColor)
    }

    @ViewBuilder
    private var profileHeader: some View {
        VStack(spacing: 6.0) {
            if let data = workoutManager.qproImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 96.0)
            }
            if let djName = workoutManager.djName {
                Text(verbatim: djName)
                    .font(.headline)
                    .lineLimit(1)
            }
            if let selectedRank {
                Text(verbatim: bothRadars ? selectedRank : "\(effectiveType.label)  ·  \(selectedRank)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var idlePlaceholder: some View {
        ScrollView {
            VStack(spacing: 8.0) {
                Image(systemName: "figure.dance")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Watch.Idle.Title")
                    .font(.headline)
                Text("Watch.Idle.Message")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                startButton
                    .padding(.top, 4.0)
            }
            .padding()
        }
    }

    private func togglePlayType() {
        playTypeRaw = effectiveType == .sp ? WatchPlayType.dp.rawValue : WatchPlayType.sp.rawValue
    }
}
