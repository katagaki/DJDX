import SwiftUI
import WidgetKit

@main
struct DJDXApp: App {

    @StateObject var navigationManager = NavigationManager()

    var body: some Scene {
        WindowGroup {
            UnifiedView()
        }
        .environmentObject(navigationManager)
    }

    init() {
        _ = IIDXPlayDataDatabase.shared
        _ = PlaySessionsDatabase.shared
        ICloudBackupManager.registerBackgroundTask()
        ICloudBackupManager.scheduleNextBackup()
        SessionOCRBackgroundTask.register()
        Task {
            await SessionCaptureProcessor.shared.recover()
        }
        Task {
            let playTypeRaw = UserDefaults.standard.string(forKey: "ScoresView.PlayTypeFilter") ?? "single"
            let playType = IIDXPlayType(rawValue: playTypeRaw) ?? .single
            let versionRaw = UserDefaults.standard.integer(forKey: "Global.IIDX.Version")
            let version = IIDXVersion(rawValue: versionRaw) ?? .sparkleShower
            await WidgetDataPublisher.shared.publishAll(playType: playType, iidxVersion: version)
        }
    }
}
