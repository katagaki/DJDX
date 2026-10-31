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
                .hidden()
                .overlay {
                    GeometryReader { proxy in
                        Canvas { context, size in
                            guard let resolvedView = context.resolveSymbol(id: id) else { return }
                            let center = CGPoint(x: size.width / 2, y: size.height / 2)
                            let radius = width * 2.0
                            context.drawLayer { layer in
                                layer.clipToLayer { mask in
                                    for point in offsets(around: center, radius: radius) {
                                        mask.draw(resolvedView, at: point)
                                    }
                                }
                                layer.fill(Path(CGRect(origin: .zero, size: size)), with: .color(color))
                            }
                            context.draw(resolvedView, at: center)
                        } symbols: {
                            content
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .tag(id)
                        }
                        .padding(-width * 3)
                    }
                }
                .accessibilityRepresentation {
                    content
                }
        } else {
            content
        }
    }

    func offsets(around center: CGPoint, radius: CGFloat) -> [CGPoint] {
        let steps = 16
        return (0..<steps).map { step in
            let angle = Double(step) / Double(steps) * 2 * .pi
            return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }
    }
}

extension View {
    public func strokeText(color: Color, width: CGFloat = 1) -> some View {
        modifier(TextStroke(width: width, color: color))
    }
}
