//
//  MainTabView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import StoreKit
import SwiftData
import SwiftUI
import TipKit

struct MainTabView: View {

    @Environment(\.requestReview) var requestReview
    @Environment(\.modelContext) var modelContext
    @Environment(\.colorScheme) var colorScheme

    @Environment(ProgressAlertManager.self) var progressAlertManager
    @EnvironmentObject var navigationManager: NavigationManager

    @AppStorage(wrappedValue: false, "ScoresView.IsTimeTravelling") var isTimeTravelling: Bool
    @AppStorage(wrappedValue: false, "Review.IsPrompted", store: .standard) var hasReviewBeenPrompted: Bool
    @AppStorage(wrappedValue: 0, "Review.LaunchCount", store: .standard) var launchCount: Int

    @State var isFirstStartCleanupComplete: Bool = false

    var body: some View {
        @Bindable var progressAlertManager = progressAlertManager
        TabView(selection: $navigationManager.selectedTab) {
            ImportView()
                .tabItem {
                    Label("Tab.Import", systemImage: "arrow.down.circle.dotted")
                }
                .tag(TabType.imports)
            ScoresView()
                .tabItem {
                    Label("Tab.Scores", image: .tabIconScores)
                }
                .tag(TabType.scores)
            AnalyticsView()
                .tabItem {
                    Label("Tab.Analytics", image: .tabIconAnalytics)
                }
                .tag(TabType.analytics)
            TowerView()
                .tabItem {
                    Label("Tab.Tower", systemImage: "chart.bar.xaxis")
                }
                .tag(TabType.tower)
            MoreView()
                .tabItem {
                    Label("Tab.More", systemImage: "ellipsis")
                }
                .tag(TabType.more)
        }
        .task {
            if !isFirstStartCleanupComplete {
                await migrateData()
                isFirstStartCleanupComplete = true
            }
            try? Tips.configure([
                .displayFrequency(.immediate),
                .datastoreLocation(.applicationDefault)
            ])
            launchCount += 1
            if launchCount > 2 && !hasReviewBeenPrompted {
                requestReview()
                hasReviewBeenPrompted = true
            }
        }
        .overlay {
            if progressAlertManager.isShowing {
                ProgressAlert(
                    title: $progressAlertManager.title,
                    message: $progressAlertManager.message
                )
            } else {
                // HACK: DO NOT REMOVE. Removing this will cause a freeze when isShowing is false.
                Color.clear
            }
        }
    }

    func migrateData() async {
        let defaults = UserDefaults.standard
        let dataMigrationKeys = ["Internal.DataMigrationForEpolisToPinkyCrush.2"]

        for dataMigrationKey in dataMigrationKeys where !defaults.bool(forKey: dataMigrationKey) {
            switch dataMigrationKey {
            case "Internal.DataMigrationForEpolisToPinkyCrush.2":
                debugPrint("Performing migration when migrating from 1.x to 32.x")
                progressAlertManager.show(
                    title: "Migration.Title",
                    message: "Migration.Description"
                ) {
                    let importGroups = try? modelContext.fetch(FetchDescriptor<ImportGroup>())
                    for importGroup in importGroups ?? [] where importGroup.iidxVersion == nil {
                        importGroup.iidxVersion = .epolis
                    }
                    progressAlertManager.hide()
                }
            default: break
            }
            UserDefaults.standard.set(true, forKey: dataMigrationKey)
        }
    }
}
