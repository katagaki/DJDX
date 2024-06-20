//
//  MainTabView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import SwiftUI

struct MainTabView: View {

    @Environment(ProgressAlertManager.self) var progressAlertManager
    @EnvironmentObject var navigationManager: NavigationManager
    @EnvironmentObject var playData: PlayDataManager

    @State var isFirstStartCleanupComplete: Bool = false

    var body: some View {
        TabView(selection: $navigationManager.selectedTab) {
            CalendarView()
                .tabItem {
                    Label("Tab.Calendar", systemImage: "calendar")
                }
                .tag(TabType.calendar)
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
            MoreView()
                .tabItem {
                    Label("Tab.More", systemImage: "ellipsis")
                }
                .tag(TabType.more)
        }
        .overlay {
            if progressAlertManager.isShowing {
                @Bindable var progressAlertManager = progressAlertManager
                ProgressAlert(
                    title: progressAlertManager.title,
                    message: progressAlertManager.message,
                    percentage: $progressAlertManager.percentage
                )
                .ignoresSafeArea(.all)
            }
        }
        .task {
            if !isFirstStartCleanupComplete {
                await playData.cleanUpOrphanedSongRecords()
                isFirstStartCleanupComplete = true
            }
        }
        .onReceive(navigationManager.$selectedTab, perform: { newValue in
            if newValue == navigationManager.previouslySelectedTab {
                navigationManager.popToRoot(for: newValue)
            }
            navigationManager.previouslySelectedTab = newValue
        })
    }
}
