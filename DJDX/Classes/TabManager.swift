//
//  TabManager.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import Foundation

class TabManager: ObservableObject {
    @Published var selectedTab: TabType = .scores
    @Published var previouslySelectedTab: TabType = .scores
}
