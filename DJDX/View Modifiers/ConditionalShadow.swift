//
//  ConditionalShadow.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/26.
//

import Foundation
import SwiftUI

// swiftlint:disable identifier_name
struct ConditionalShadow: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var color: Color
    var radius: CGFloat = 2.0
    var x: CGFloat = 0.0
    var y: CGFloat = 0.0

    func body(content: Content) -> some View {
        switch colorScheme {
        case .light:
            content
                .shadow(color: color, radius: radius, x: x, y: y)
        case .dark:
            content
        @unknown default:
            content
        }
    }
}

extension View {
    func conditionalShadow(_ color: Color, radius: CGFloat = 2.0, x: CGFloat = 0.0, y: CGFloat = 0.0) -> some View {
        modifier(ConditionalShadow(color: color, radius: radius, x: x, y: y))
    }
}
// swiftlint:enable identifier_name
