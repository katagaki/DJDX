import SwiftUI

struct IIDXChartTraitIcon: View {

    var trait: IIDXChartTrait
    var size: CGFloat = 26.0

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(LinearGradient(colors: [trait.color.mix(with: .white, by: 0.15), trait.color],
                                 startPoint: .top, endPoint: .bottom))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .strokeBorder(.black.opacity(0.18), lineWidth: 0.5)
            }
            .overlay {
                glyph()
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 0.5, y: 0.5)
            }
            .frame(width: size, height: size)
    }

    @ViewBuilder
    private func glyph() -> some View {
        switch trait {
        case .backloaded:
            graphGlyph(BackloadedGlyph.self)
        case .gradualSoflan:
            graphGlyph(GradualSoflanGlyph.self)
        case .suddenSoflan:
            graphGlyph(SuddenSoflanGlyph.self)
        case .chargeCombo:
            ChargeComboGlyph()
                .frame(width: size * 0.54, height: size * 0.52)
        case .scratchCombo:
            ScratchComboGlyph()
                .frame(width: size * 0.6, height: size * 0.46)
        case .burst:
            symbolGlyph("bolt.fill")
        case .stamina:
            symbolGlyph("flame.fill")
        case .chaotic:
            symbolGlyph("shuffle")
        }
    }

    private func symbolGlyph(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.5, weight: .bold))
    }

    private func graphGlyph<Glyph: GraphGlyph>(_ glyph: Glyph.Type) -> some View {
        ZStack {
            Glyph(closed: true)
                .opacity(0.45)
            Glyph(closed: false)
                .stroke(style: StrokeStyle(lineWidth: size * 0.07, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size * 0.62, height: size * 0.5)
    }
}

// MARK: - Glyphs

protocol GraphGlyph: Shape {
    var closed: Bool { get }
    init(closed: Bool)
}

extension GraphGlyph {
    func point(_ horizontal: CGFloat, _ vertical: CGFloat, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + horizontal * rect.width, y: rect.minY + vertical * rect.height)
    }

    func closing(_ path: inout Path, in rect: CGRect, from startX: CGFloat) {
        guard closed else { return }
        path.addLine(to: point(1.0, 1.0, in: rect))
        path.addLine(to: point(startX, 1.0, in: rect))
        path.closeSubpath()
    }
}

struct BackloadedGlyph: GraphGlyph {
    var closed: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: point(0.0, 0.78, in: rect))
        path.addQuadCurve(to: point(0.14, 0.78, in: rect), control: point(0.07, 0.66, in: rect))
        path.addQuadCurve(to: point(0.28, 0.78, in: rect), control: point(0.21, 0.90, in: rect))
        path.addQuadCurve(to: point(0.42, 0.78, in: rect), control: point(0.35, 0.66, in: rect))
        path.addQuadCurve(to: point(0.54, 0.80, in: rect), control: point(0.48, 0.88, in: rect))
        path.addCurve(to: point(0.78, 0.06, in: rect),
                      control1: point(0.64, 0.72, in: rect), control2: point(0.70, 0.06, in: rect))
        path.addCurve(to: point(1.0, 0.82, in: rect),
                      control1: point(0.88, 0.06, in: rect), control2: point(0.90, 0.80, in: rect))
        closing(&path, in: rect, from: 0.0)
        return path
    }
}

struct GradualSoflanGlyph: GraphGlyph {
    var closed: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: point(0.0, 0.86, in: rect))
        path.addCurve(to: point(1.0, 0.08, in: rect),
                      control1: point(0.55, 0.86, in: rect), control2: point(0.62, 0.08, in: rect))
        closing(&path, in: rect, from: 0.0)
        return path
    }
}

struct SuddenSoflanGlyph: GraphGlyph {
    var closed: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: point(0.0, 0.82, in: rect))
        path.addLine(to: point(0.46, 0.82, in: rect))
        path.addLine(to: point(0.46, 0.12, in: rect))
        path.addLine(to: point(1.0, 0.12, in: rect))
        closing(&path, in: rect, from: 0.0)
        return path
    }
}

struct ChargeComboGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let chargeWidth = rect.width * 0.26
        path.addRoundedRect(in: CGRect(x: rect.minX, y: rect.minY, width: chargeWidth, height: rect.height),
                            cornerSize: CGSize(width: chargeWidth * 0.35, height: chargeWidth * 0.35))
        let noteHeight = rect.height * 0.17
        let noteWidth = rect.width * 0.5
        for (index, offset) in [0.42, 0.5, 0.42].enumerated() {
            let originY = rect.minY + rect.height * (0.08 + Double(index) * 0.34)
            path.addRoundedRect(in: CGRect(x: rect.minX + rect.width * offset, y: originY,
                                           width: noteWidth, height: noteHeight),
                                cornerSize: CGSize(width: noteHeight * 0.4, height: noteHeight * 0.4))
        }
        return path
    }
}

struct ScratchComboGlyph: View {
    var body: some View {
        GeometryReader { geometry in
            let diameter = min(geometry.size.height, geometry.size.width * 0.52)
            let lineWidth = diameter * 0.16
            HStack(spacing: geometry.size.width * 0.1) {
                Circle()
                    .strokeBorder(lineWidth: lineWidth)
                    .overlay {
                        Circle()
                            .frame(width: diameter * 0.26, height: diameter * 0.26)
                    }
                    .frame(width: diameter, height: diameter)
                VStack(spacing: diameter * 0.14) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: lineWidth * 0.4, style: .continuous)
                            .frame(height: diameter * 0.2)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Trait Display

extension IIDXChartTrait {
    var localizedName: LocalizedStringKey {
        switch self {
        case .backloaded: "Scores.Viewer.ChartType.Backloaded"
        case .burst: "Scores.Viewer.ChartType.Burst"
        case .stamina: "Scores.Viewer.ChartType.Stamina"
        case .chaotic: "Scores.Viewer.ChartType.Chaotic"
        case .scratchCombo: "Scores.Viewer.ChartType.ScratchCombo"
        case .chargeCombo: "Scores.Viewer.ChartType.ChargeCombo"
        case .gradualSoflan: "Scores.Viewer.ChartType.GradualSoflan"
        case .suddenSoflan: "Scores.Viewer.ChartType.SuddenSoflan"
        }
    }

    var color: Color {
        switch self {
        case .backloaded: .orange
        case .burst: .init(red: 230 / 255, green: 175 / 255, blue: 0 / 255)
        case .stamina: .pink
        case .chaotic: .init(red: 52 / 255, green: 178 / 255, blue: 89 / 255)
        case .scratchCombo: .init(red: 221 / 255, green: 0 / 255, blue: 0 / 255)
        case .chargeCombo: .init(red: 137 / 255, green: 87 / 255, blue: 221 / 255)
        case .gradualSoflan: .init(red: 0 / 255, green: 134 / 255, blue: 229 / 255)
        case .suddenSoflan: .init(red: 88 / 255, green: 86 / 255, blue: 214 / 255)
        }
    }
}
