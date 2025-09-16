//
//  AutomaticNavigationTransition.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/10/06.
//

import SwiftUI

struct AutomaticNavigationTransition: ViewModifier {

    var id: AnyHashable
    var namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            content
        }
    }
}

extension View {
    func automaticNavigationTransition(id: AnyHashable, in namespace: Namespace.ID) -> some View {
        modifier(AutomaticNavigationTransition(id: id, namespace: namespace))
    }
}
