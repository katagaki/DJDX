//
//  DJDXApp.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/18.
//

import SwiftData
import SwiftUI
import WidgetKit

@main
struct DJDXApp: App {

    @StateObject var navigationManager = NavigationManager()
    @State var progressAlertManager = ProgressAlertManager()

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
        .environmentObject(navigationManager)
        .environment(progressAlertManager)
        .onChange(of: navigationManager.selectedTab) { _, _ in
            navigationManager.saveToDefaults()
        }
    }

    init() {
        _ = PlayDataDatabase.shared
        Task {
            let playTypeRaw = UserDefaults.standard.string(forKey: "ScoresView.PlayTypeFilter") ?? "single"
            let playType = IIDXPlayType(rawValue: playTypeRaw) ?? .single
            let versionRaw = UserDefaults.standard.integer(forKey: "Global.IIDX.Version")
            let version = IIDXVersion(rawValue: versionRaw) ?? .sparkleShower
            await WidgetDataPublisher.shared.publishAll(playType: playType, iidxVersion: version)
        }
    }
}

let sharedModelContainer: ModelContainer = {
    let schema = Schema([
        ImportGroup.self,
        IIDXSongRecord.self,
        IIDXSong.self,
        IIDXTowerEntry.self
    ])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

    do {
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
        fatalError("Could not create ModelContainer: \(error)")
    }
}()
