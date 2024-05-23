//
//  NavigationManager.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import Foundation

class NavigationManager: ObservableObject {
    @Published var selectedTab: TabType = .scores
    @Published var previouslySelectedTab: TabType = .scores

    @Published var tabPaths: [TabType: [ViewPath]] = [
        .calendar: [],
        .scores: [],
        .analytics: [],
        .more: []
    ]

    subscript(tabType: TabType) -> [ViewPath] {
        get {
            return tabPaths[tabType] ?? []
        }
        set(newViewPath) {
            tabPaths[tabType] = newViewPath
        }
    }

    func popToRoot(for tab: TabType) {
        tabPaths[tab]?.removeAll()
    }

    func push(_ viewPath: ViewPath, for tab: TabType) {
        tabPaths[tab]?.append(viewPath)
    }

}
