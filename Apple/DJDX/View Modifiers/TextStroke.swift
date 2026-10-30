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
                                guard let resolvedView = context.resolveSymbol(id: id) else { return }
                                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                                let radius = width * 2
                                let steps = 16
                                for step in 0..<steps {
                                    let angle = Double(step) / Double(steps) * 2 * .pi
                                    context.draw(
                                        resolvedView,
                                        at: CGPoint(
                                            x: center.x + radius * cos(angle),
                                            y: center.y + radius * sin(angle)
                                        )
                                    )
                                }
                            } symbols: {
                                content
                                    .tag(id)
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
