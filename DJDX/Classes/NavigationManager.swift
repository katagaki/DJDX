//
//  NavigationManager.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/19.
//

import Foundation

class NavigationManager: ObservableObject {

    @Published var scoresTabPath: [ViewPath] = []
    @Published var importerTabPath: [ViewPath] = []
    @Published var moreTabPath: [ViewPath] = []

    func popToRoot(for tab: TabType) {
        switch tab {
        case .scores:
            scoresTabPath.removeAll()
        case .importer:
            importerTabPath.removeAll()
        case .more:
            moreTabPath.removeAll()
        }
    }

    func push(_ viewPath: ViewPath, for tab: TabType) {
        switch tab {
        case .scores:
            scoresTabPath.append(viewPath)
        case .importer:
            importerTabPath.append(viewPath)
        case .more:
            moreTabPath.append(viewPath)
        }
    }

}
