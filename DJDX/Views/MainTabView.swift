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
            ChartsView()
                .tabItem {
                    Label("Tab.Charts", image: .tabIconCharts)
                }
                .tag(TabType.charts)
            AnalyticsView()
                .tabItem {
                    Label("Tab.Analytics", systemImage: "chart.xyaxis.line")
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
        .onReceive(navigationManager.$selectedTab, perform: { newValue in
            if newValue == navigationManager.previouslySelectedTab {
                navigationManager.popToRoot(for: newValue)
            }
            navigationManager.previouslySelectedTab = newValue
        })
    }
}
