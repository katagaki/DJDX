//
//  TextStroke.swift
//  DJDX
//
//  Created by シン・ジャスティン on 2024/10/19.
//

import Foundation
import SwiftUI

struct TextStroke: ViewModifier {
    let id = UUID()
    var width: CGFloat
    var color: Color

    init(width: CGFloat, color: Color) {
        self.width = width
        self.color = color
    }

    func body(content: Content) -> some View {
        if width > .zero {
            content
                .padding(width * 2)
                .background(
                    Rectangle()
                        .foregroundColor(color)
                        .mask {
                            Canvas { context, size in
                                context.addFilter(.alphaThreshold(min: 0.01))
                                context.drawLayer { ctx in
                                    if let resolvedView = context.resolveSymbol(id: id) {
                                        ctx.draw(resolvedView, at: .init(x: size.width / 2, y: size.height / 2))
                                    }
                                }
                            } symbols: {
                                content
                                    .tag(id)
                                    .blur(radius: width)
                            }
                        }
                )
        } else {
            content
        }
    }
}

extension View {
    public func strokeText(color: Color, width: CGFloat = 1) -> some View {
        modifier(TextStroke(width: width, color: color))
    }
}
