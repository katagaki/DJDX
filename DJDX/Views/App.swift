//
//  DJDXApp.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/18.
//

import SwiftUI
import SwiftData

@main
struct DJDXApp: App {

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            IIDXSongRecord.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @StateObject var navigationManager = NavigationManager()
    @StateObject var calendar = CalendarManager()

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
        .environmentObject(navigationManager)
        .environmentObject(calendar)
    }
}
