import SwiftUI

struct AutomaticSheetMatchedTransitionSource: ViewModifier {

    var id: AnyHashable
    var namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}

struct AutomaticSheetNavigationTransition: ViewModifier {

    var id: AnyHashable
    var namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            content
        }
    }
}

extension View {
    func automaticSheetMatchedTransitionSource(id: AnyHashable, in namespace: Namespace.ID) -> some View {
        modifier(AutomaticSheetMatchedTransitionSource(id: id, namespace: namespace))
    }

    func automaticSheetNavigationTransition(id: AnyHashable, in namespace: Namespace.ID) -> some View {
        modifier(AutomaticSheetNavigationTransition(id: id, namespace: namespace))
    }
}
