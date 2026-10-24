import SwiftUI

class NavigationManager: ObservableObject {

    @Published var path = NavigationPath()

    func popToRoot() {
        path = NavigationPath()
    }

    func push<V: Hashable>(_ value: V) {
        path.append(value)
    }
}
