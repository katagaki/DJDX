//
//  ConditionalBottomAccessory.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2025/09/16.
//

import SwiftUI

struct ConditionalBottomAccessory: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
        } else {
            content
                .safeAreaInset(edge: .bottom, spacing: 0.0) {
                    TabBarAccessory(placement: .bottom) {
                        Color.clear
                            .frame(height: 0.0)
                    }
                }
        }
    }
}

extension View {
    func conditionalBottomTabBarAccessory() -> some View {
        modifier(ConditionalBottomAccessory())
    }
}
