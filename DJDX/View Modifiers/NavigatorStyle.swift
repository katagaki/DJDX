//
//  NavigatorStyle.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/12/20.
//

import SwiftUI

struct NavigatorStyle: ViewModifier {

    var title: LocalizedStringKey
    var isGrouped: Bool
    var isInline: Bool

    func body(content: Content) -> some View {
        Group {
            switch isGrouped {
            case true:
                content
                    .listStyle(.insetGrouped)
            case false:
                content
                    .listStyle(.plain)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(isInline ? .inline : .automatic)
        .background(
            .linearGradient(
                colors: [.backgroundGradientTop, .backgroundGradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

extension View {
    func navigator(
        _ title: LocalizedStringKey,
        group isGrouped: Bool = false,
        inline isInline: Bool = false
    ) -> some View {
        modifier(NavigatorStyle(title: title, isGrouped: isGrouped, isInline: isInline))
    }
}
