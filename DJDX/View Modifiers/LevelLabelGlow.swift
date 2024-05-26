//
//  LevelLabelGlow.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/05/26.
//

import Foundation
import SwiftUI

struct LevelLabelGlow: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var color: Color

    func body(content: Content) -> some View {
        switch colorScheme {
        case .light:
            content
                .foregroundStyle(color)
        case .dark:
            content
                .foregroundStyle(.white)
                .drawingGroup()
                .shadow(color: color, radius: 6.0, x: 0.0, y: 0.0)
                .overlay {
                    content
                        .foregroundStyle(color)
                        .opacity(0.2)
                }
        @unknown default:
            content
        }
    }
}
