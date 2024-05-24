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
                    Label("カレンダー", systemImage: "calendar")
                }
                .tag(TabType.calendar)
            ScoresView()
                .tabItem {
                    Label("プレーデータ", image: "TabIcon.Scores")
                }
                .tag(TabType.scores)
            ChartsView()
                .tabItem {
                    Label("アナリティクス", systemImage: "chart.xyaxis.line")
                }
                .tag(TabType.analytics)
            MoreView()
                .tabItem {
                    Label("その他", systemImage: "ellipsis")
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
