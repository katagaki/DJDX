//
//  MainTabView.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ScoresView()
                .tabItem {
                    Label("スコア", systemImage: "list.star")
                }
            MoreView()
            .tabItem {
                Label("その他", systemImage: "ellipsis")
            }
        }
    }
}

#Preview {
    MainTabView()
}
