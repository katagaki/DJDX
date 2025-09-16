//
//  ConditionalSafeAreaIgnorance.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2025/09/16.
//

import SwiftUI

struct ConditionalSafeAreaIgnoranceModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .ignoresSafeArea()
        } else {
            content
        }
    }
}

extension View {
    func ignoreSafeAreaConditionally() -> some View {
        modifier(ConditionalSafeAreaIgnoranceModifier())
    }
}
