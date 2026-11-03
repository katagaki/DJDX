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
                .frame(width: size * 0.62, height: size * 0.54)
        case .scratchCombo:
            ScratchComboGlyph()
                .frame(width: size * 0.6, height: size * 0.46)
        case .legacyNotes:
            LegacyNotesGlyph()
                .frame(width: size * 0.66, height: size * 0.46)
        case .stairs, .consecutiveChords, .adjacentPairs, .rapidRepeats:
            NoteGridGlyph(columns: 4, rows: trait.noteGridRows)
                .frame(width: size * 0.7, height: size * 0.56)
        case .burst, .stamina, .chaotic:
            Image(systemName: trait.symbolName)
                .font(.system(size: size * 0.5, weight: .bold))
        }
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
        let chargeWidth = rect.width * 0.24
        path.addRoundedRect(in: CGRect(x: rect.midX - chargeWidth / 2.0, y: rect.minY,
                                       width: chargeWidth, height: rect.height),
                            cornerSize: CGSize(width: chargeWidth * 0.35, height: chargeWidth * 0.35))
        let noteWidth = rect.width * 0.3
        let noteHeight = rect.height * 0.16
        for (index, isLeft) in [true, false, true].enumerated() {
            let originX = isLeft ? rect.minX : rect.maxX - noteWidth
            let originY = rect.minY + rect.height * (0.06 + Double(index) * 0.36)
            path.addRoundedRect(in: CGRect(x: originX, y: originY, width: noteWidth, height: noteHeight),
                                cornerSize: CGSize(width: noteHeight * 0.4, height: noteHeight * 0.4))
        }
        return path
    }
}

struct NoteGridGlyph: Shape {
    var columns: Int
    var rows: [[Int]]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let columnWidth = rect.width / CGFloat(columns)
        let rowHeight = rect.height / CGFloat(rows.count)
        let noteWidth = columnWidth * 0.9
        let noteHeight = min(rowHeight * 0.7, noteWidth * 0.5)
        for (rowIndex, rowColumns) in rows.enumerated() {
            let originY = rect.minY + rowHeight * CGFloat(rowIndex) + (rowHeight - noteHeight) / 2.0
            for column in rowColumns {
                let originX = rect.minX + columnWidth * CGFloat(column) + (columnWidth - noteWidth) / 2.0
                path.addRoundedRect(in: CGRect(x: originX, y: originY, width: noteWidth, height: noteHeight),
                                    cornerSize: CGSize(width: noteHeight * 0.35, height: noteHeight * 0.35))
            }
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

struct LegacyNotesGlyph: View {
    var body: some View {
        GeometryReader { geometry in
            let diameter = min(geometry.size.height, geometry.size.width * 0.5)
            let lineWidth = diameter * 0.16
            HStack(spacing: geometry.size.width * 0.1) {
                Circle()
                    .strokeBorder(lineWidth: lineWidth)
                    .overlay {
                        Circle()
                            .frame(width: diameter * 0.26, height: diameter * 0.26)
                    }
                    .frame(width: diameter, height: diameter)
                Text(verbatim: "3")
                    .font(.system(size: diameter * 1.05, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.5)
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
        case .stairs: "Scores.Viewer.ChartType.Stairs"
        case .consecutiveChords: "Scores.Viewer.ChartType.ConsecutiveChords"
        case .adjacentPairs: "Scores.Viewer.ChartType.AdjacentPairs"
        case .rapidRepeats: "Scores.Viewer.ChartType.RapidRepeats"
        case .scratchCombo: "Scores.Viewer.ChartType.ScratchCombo"
        case .legacyNotes: "Scores.Viewer.ChartType.LegacyNotes"
        case .chargeCombo: "Scores.Viewer.ChartType.ChargeCombo"
        case .gradualSoflan: "Scores.Viewer.ChartType.GradualSoflan"
        case .suddenSoflan: "Scores.Viewer.ChartType.SuddenSoflan"
        }
    }

    var noteGridRows: [[Int]] {
        switch self {
        case .stairs: [[0], [1], [2], [3]]
        case .consecutiveChords: [[0, 2], [1, 3], [0, 2]]
        case .adjacentPairs: [[2, 3], [0, 1], [1, 2]]
        case .rapidRepeats: [[1], [1], [2], [2]]
        default: []
        }
    }

    var symbolName: String {
        switch self {
        case .burst: "bolt.fill"
        case .stamina: "flame.fill"
        case .chaotic: "shuffle"
        default: ""
        }
    }

    var color: Color {
        switch self {
        case .backloaded: .orange
        case .burst: .init(red: 230 / 255, green: 175 / 255, blue: 0 / 255)
        case .stamina: .pink
        case .chaotic: .init(red: 52 / 255, green: 178 / 255, blue: 89 / 255)
        case .stairs: .init(red: 0 / 255, green: 168 / 255, blue: 196 / 255)
        case .consecutiveChords: .init(red: 162 / 255, green: 126 / 255, blue: 84 / 255)
        case .adjacentPairs: .init(red: 200 / 255, green: 64 / 255, blue: 170 / 255)
        case .rapidRepeats: .init(red: 96 / 255, green: 112 / 255, blue: 140 / 255)
        case .scratchCombo: .init(red: 221 / 255, green: 0 / 255, blue: 0 / 255)
        case .legacyNotes: .init(red: 150 / 255, green: 40 / 255, blue: 70 / 255)
        case .chargeCombo: .init(red: 137 / 255, green: 87 / 255, blue: 221 / 255)
        case .gradualSoflan: .init(red: 0 / 255, green: 134 / 255, blue: 229 / 255)
        case .suddenSoflan: .init(red: 88 / 255, green: 86 / 255, blue: 214 / 255)
        }
    }
}
