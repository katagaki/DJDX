import SwiftUI

struct SessionsHelpMenu: View {
    @AppStorage(wrappedValue: false, IIDXSessionWorkoutBridge.healthKitEnabledKey) private var healthKitEnabled: Bool

    var body: some View {
        Menu {
            Text("Sessions.Welcome.Message")
            Divider()
            Toggle(isOn: $healthKitEnabled) {
                Label("Sessions.HealthKit.Toggle", systemImage: "heart.fill")
            }
        } label: {
            Label("Sessions.Help", systemImage: "questionmark.circle")
        }
        .menuOrder(.fixed)
        .onChange(of: healthKitEnabled) { _, enabled in
            if enabled {
                Task { _ = await IIDXSessionWorkoutBridge.shared.requestAuthorization() }
            }
            IIDXSessionWorkoutBridge.shared.syncProfileToWatch()
        }
    }
}
