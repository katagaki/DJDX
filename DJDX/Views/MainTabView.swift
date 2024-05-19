//
//  MainTabView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import SwiftUI

struct MainTabView: View {

    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var navigationManager: NavigationManager

    var body: some View {
        TabView(selection: $tabManager.selectedTab) {
            ScoresView()
                .tabItem {
                    Label("スコアデータ", systemImage: "list.star")
                }
                .tag(TabType.scores)
            ChartsView()
                .tabItem {
                    Label("アナリティクス", systemImage: "chart.xyaxis.line")
                }
                .tag(TabType.analytics)
            ImportView()
                .tabItem {
                    Label("インポート", systemImage: "square.and.arrow.down")
                }
                .tag(TabType.importer)
            MoreView()
                .tabItem {
                    Label("その他", systemImage: "ellipsis")
                }
                .tag(TabType.more)
        }
        .onReceive(tabManager.$selectedTab, perform: { newValue in
            if newValue == tabManager.previouslySelectedTab {
                navigationManager.popToRoot(for: newValue)
            }
            tabManager.previouslySelectedTab = newValue
        })
    }
}

#Preview {
    MainTabView()
}
