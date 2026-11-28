import SwiftUI

enum LevelBadgeLayout {
    case vertical
    case horizontal
    case compact
}

struct LevelBadge: View {
    let name: String
    let level: String
    let tint: Color
    var layout: LevelBadgeLayout = .vertical

    var body: some View {
        let radius: CGFloat = layout == .compact ? 4.0 : 6.0
        Group {
            switch layout {
            case .vertical:
                VStack(spacing: 0.0) {
                    nameText(size: 7.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 6.0)
                        .frame(height: 14.0)
                    number(size: 21.0)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 7.0)
                        .frame(height: 30.0)
                }
                .frame(width: 78.0)
                .background {
                    ZStack(alignment: .topLeading) {
                        darkFill
                        LevelBadgeSlash(isVertical: true, split: 14.5, lean: 4.5)
                            .fill(slashFill)
                    }
                }
            case .horizontal:
                HStack(spacing: 0.0) {
                    nameText(size: 10.0)
                        .padding(.leading, 9.0)
                        .padding(.trailing, 9.0)
                        .frame(maxHeight: .infinity)
                        .background { slash(lean: 5.0) }
                    number(size: 20.0)
                        .padding(.leading, 9.0)
                        .padding(.trailing, 10.0)
                }
                .frame(height: 32.0)
                .background { darkFill }
            case .compact:
                HStack(spacing: 0.0) {
                    nameText(size: 7.5)
                        .padding(.leading, 5.0)
                        .padding(.trailing, 5.5)
                        .frame(maxHeight: .infinity)
                        .background { slash(lean: 3.0) }
                    number(size: 13.0)
                        .padding(.leading, 5.5)
                        .padding(.trailing, 6.0)
                }
                .frame(height: 20.0)
                .background { darkFill }
            }
        }
        .clipShape(.rect(cornerRadius: radius))
        .overlay {
            RoundedRectangle(cornerRadius: radius).strokeBorder(tint.opacity(0.6), lineWidth: 1.0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(name) \(level)"))
    }

    private var soft: Color { tint.mix(with: .white, by: 0.35) }

    private var darkFill: LinearGradient {
        LinearGradient(colors: [Color(hex: 0x2A2D33), Color(hex: 0x111215)], startPoint: .top, endPoint: .bottom)
    }

    private var slashFill: LinearGradient {
        LinearGradient(colors: [soft, tint], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func slash(lean: CGFloat) -> some View {
        GeometryReader { proxy in
            LevelBadgeSlash(isVertical: false, split: proxy.size.width, lean: lean)
                .fill(slashFill)
        }
    }

    private func nameText(size: CGFloat) -> some View {
        Text(verbatim: name)
            .font(.system(size: size, weight: .black))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(.white)
            .strokeText(color: tint.mix(with: .black, by: 0.55), width: size * 0.05)
    }

    private func number(size: CGFloat) -> some View {
        LevelNumber(level: level, size: size, tint: tint)
            .shadow(color: tint.opacity(0.8), radius: size * 0.18)
    }
}

struct LevelNumber: View {
    let level: String
    let size: CGFloat
    var tint: Color = Color(hex: 0x9AA3B2)
    var isColored: Bool = false

    private var isPlus: Bool { level.hasSuffix("+") }
    private var digits: String { isPlus ? String(level.dropLast()) : level }

    private var fill: LinearGradient {
        let top: Color = isColored ? tint.mix(with: .white, by: 0.3) : .white
        let middle: Color = isColored ? tint : tint.mix(with: .white, by: 0.7)
        let bottom: Color = isColored ? tint.mix(with: .black, by: 0.2) : tint.mix(with: .white, by: 0.35)
        return LinearGradient(
            stops: [
                .init(color: top, location: 0.0),
                .init(color: top, location: 0.52),
                .init(color: middle, location: 0.56),
                .init(color: bottom, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: 1.0) {
            let outline = HitlineOutline(text: digits, size: size)
            outline
                .fill(fill)
                .frame(width: outline.width, height: size)
            if isPlus {
                LevelBadgePlus(bar: size * 0.12)
                    .fill(fill)
                    .frame(width: size * 0.4, height: size * 0.4)
            }
        }
    }
}

struct LevelNumberBadge: View {
    let level: String
    var isCompact: Bool = true

    var body: some View {
        let radius: CGFloat = isCompact ? 4.0 : 6.0
        HStack(spacing: isCompact ? 5.0 : 7.0) {
            Text(verbatim: "LEVEL")
                .font(.system(size: isCompact ? 7.5 : 10.0, weight: .black))
                .foregroundStyle(.white.opacity(0.7))
            LevelNumber(level: level, size: isCompact ? 13.0 : 20.0)
        }
        .padding(.horizontal, isCompact ? 6.0 : 9.0)
        .frame(height: isCompact ? 20.0 : 32.0)
        .background(LinearGradient(colors: [Color(hex: 0x2A2D33), Color(hex: 0x111215)],
                                   startPoint: .top, endPoint: .bottom))
        .clipShape(.rect(cornerRadius: radius))
        .overlay {
            RoundedRectangle(cornerRadius: radius).strokeBorder(.white.opacity(0.25), lineWidth: 1.0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "LEVEL \(level)"))
        .fixedSize()
    }
}

struct LevelBadgeSlash: Shape {
    var isVertical: Bool
    var split: CGFloat
    var lean: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        if isVertical {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + split - lean))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + split + lean))
        } else {
            path.addLine(to: CGPoint(x: rect.minX + split + lean, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + split - lean, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}

struct LevelBadgePlus: Shape {
    let bar: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(CGRect(x: rect.midX - bar / 2.0, y: rect.minY, width: bar, height: rect.height))
        path.addRect(CGRect(x: rect.minX, y: rect.midY - bar / 2.0, width: rect.width, height: bar))
        return path.union(Path())
    }
}
