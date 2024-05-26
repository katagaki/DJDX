//
//  ConditionalShadow.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/26.
//

import Foundation
import SwiftUI

struct ConditionalShadow: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var color: Color
    var radius: CGFloat = 2.0
    // swiftlint:disable identifier_name
    var x: CGFloat = 0.0
    var y: CGFloat = 0.0
    // swiftlint:enable identifier_name

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
