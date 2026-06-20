import SwiftUI
import WidgetKit

@main
struct DJDXApp: App {

    @StateObject var navigationManager = NavigationManager()

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            UnifiedView()
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        IIDXSessionLiveActivityController.shared.reconcile()
                    }
                }
        }
        .environmentObject(navigationManager)
    }

    init() {
        DataMigration.runVersion334CleanupIfNeeded()
        _ = IIDXPlayDataDatabase.shared
        _ = IIDXPlaySessionsDatabase.shared
        _ = IIDXSessionWorkoutBridge.shared
        ICloudBackupManager.registerBackgroundTask()
        ICloudBackupManager.scheduleNextBackup()
        IIDXSessionOCRBackgroundTask.register()
        Task {
            await IIDXSessionCaptureProcessor.shared.recover()
        }
        Task { @MainActor in
            IIDXSessionLiveActivityController.shared.reconcile()
        }
        Task {
            let playTypeRaw = UserDefaults.standard.string(forKey: "ScoresView.PlayTypeFilter") ?? "single"
            let playType = IIDXPlayType(rawValue: playTypeRaw) ?? .single
            let versionRaw = UserDefaults.standard.integer(forKey: "Global.IIDX.Version")
            let version = IIDXVersion(rawValue: versionRaw) ?? .zinrai
            await WidgetDataPublisher.shared.publishAll(playType: playType, iidxVersion: version)
        }
    }
}
