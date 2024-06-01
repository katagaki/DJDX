//
//  MainTabView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import SwiftUI

struct MainTabView: View {

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
                    Label("Tab.Scores", image: "TabIcon.Scores")
                }
                .tag(TabType.scores)
            AnalyticsView()
                .tabItem {
                    Label("Tab.Analytics", systemImage: "chart.xyaxis.line")
                }
                .tag(TabType.analytics)
            Color.clear
                .tabItem {
                    Label("Tab.Charts", image: "TabIcon.Charts")
                }
//                .tag(TabType.charts)
            MoreView()
                .tabItem {
                    Label("Tab.More", systemImage: "ellipsis")
                }
                .tag(TabType.more)
        }
        .onReceive(navigationManager.$selectedTab, perform: { newValue in
            if newValue == navigationManager.previouslySelectedTab {
                navigationManager.popToRoot(for: newValue)
            }
            navigationManager.previouslySelectedTab = newValue
        })
    }
}
