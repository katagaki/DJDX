import SwiftUI

enum ChartPlayfield {
    static let width: Double = 390
    static let height: Double = 844
    static let laneWidths: [Double] = [54, 38, 32, 38, 32, 38, 32, 38]
    static let divider: Double = 3
    static let gutter: Double = 14
    static let frameWidth: Double = 2 * gutter + laneWidths.reduce(0, +) + 9 * divider
    static let frameX: Double = (width - frameWidth) / 2
    static let laneX0: [Double] = {
        var x = frameX + gutter + divider
        var result: [Double] = []
        for laneWidth in laneWidths {
            result.append(x)
            x += laneWidth + divider
        }
        return result
    }()
    static let leftGutterX: Double = frameX + gutter / 2
    static let rightGutterX: Double = frameX + frameWidth - gutter / 2
    static let frameTop: Double = 40
    static let visibleTop: Double = 64
    static let judgeY: Double = 700
    static let frameBottom: Double = 760
    static let pitch: Double = 112
    static let noteHeight: Double = 14
    static let measure: Double = 8 * pitch
    static let rowsPerSecond: Double = 8
    static let speed: Double = rowsPerSecond * pitch
    static let fiducialSize: Double = 14
    static let fiducials: [CGPoint] = [
        CGPoint(x: leftGutterX, y: 50), CGPoint(x: rightGutterX, y: 50),
        CGPoint(x: rightGutterX, y: 742), CGPoint(x: leftGutterX, y: 742)
    ]

    static func laneX1(_ lane: Int) -> Double { laneX0[lane] + laneWidths[lane] }

    static func noteColor(_ lane: Int) -> Color {
        if lane == 0 { return Color(red: 1.0, green: 0.18, blue: 0.16) }
        return lane % 2 == 1 ? Color(red: 0.95, green: 0.95, blue: 0.97) : Color(red: 0.22, green: 0.48, blue: 1.0)
    }

    static func fittedRect(in size: CGSize) -> CGRect {
        let scale = min(size.width / width, size.height / height)
        let fitted = CGSize(width: width * scale, height: height * scale)
        return CGRect(x: (size.width - fitted.width) / 2, y: (size.height - fitted.height) / 2,
                      width: fitted.width, height: fitted.height)
    }

    static func draw(in context: inout GraphicsContext, size: CGSize, bits: [Bool], time: Double) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
        let rect = fittedRect(in: size)
        context.translateBy(x: rect.minX, y: rect.minY)
        context.scaleBy(x: rect.width / width, y: rect.height / height)

        func fill(_ x0: Double, _ x1: Double, _ y0: Double, _ y1: Double, _ color: Color) {
            context.fill(Path(CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)), with: .color(color))
        }
        func grey(_ value: Double) -> Color { Color(red: value, green: value, blue: value) }

        let right = frameX + frameWidth
        fill(frameX, frameX + gutter, frameTop, frameBottom, grey(0.035))
        fill(right - gutter, right, frameTop, frameBottom, grey(0.035))
        for i in 0...8 {
            let x = i < 8 ? laneX0[i] - divider : laneX1(7)
            fill(x, x + divider, frameTop, frameBottom, grey(0.24))
        }
        for lane in 0..<8 {
            let x0 = laneX0[lane], x1 = laneX1(lane)
            fill(x0, x1, frameTop, visibleTop, grey(0.11))
            fill(x0, x1, visibleTop, judgeY, lane == 0 ? Color(red: 0.07, green: 0.04, blue: 0.045) : grey(0.05))
            if lane == 0 {
                let center = CGPoint(x: (x0 + x1) / 2, y: 731)
                context.fill(Path(ellipseIn: CGRect(x: center.x - 23, y: center.y - 23, width: 46, height: 46)), with: .color(noteColor(0)))
                context.fill(Path(ellipseIn: CGRect(x: center.x - 20, y: center.y - 20, width: 40, height: 40)), with: .color(grey(0.12)))
                context.fill(Path(ellipseIn: CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)), with: .color(grey(0.4)))
            } else if lane % 2 == 1 {
                fill(x0 + 3, x1 - 3, 718, 756, grey(0.78))
            } else {
                fill(x0 + 3, x1 - 3, 708, 744, Color(red: 0.14, green: 0.28, blue: 0.7))
            }
        }
        let half = fiducialSize / 2
        for point in fiducials {
            fill(point.x - half, point.x + half, point.y - half, point.y + half, Color(red: 0.12, green: 0.95, blue: 0.3))
        }

        let rows = bits.count / 8
        if rows > 0 {
            var notes = context
            notes.clip(to: Path(CGRect(x: frameX, y: visibleTop, width: frameWidth, height: judgeY - visibleTop)))
            let offset = speed * time
            let low = Int(((offset - pitch) / pitch).rounded(.down))
            let high = Int(((judgeY + offset - visibleTop + pitch) / pitch).rounded(.up))
            for k in low...high {
                let y = judgeY - Double(k) * pitch + offset
                let row = ((k % rows) + rows) % rows
                if row % 8 == 0 {
                    let barY = y + pitch / 2
                    notes.fill(Path(CGRect(x: laneX0[0], y: barY - 1, width: laneX1(7) - laneX0[0], height: 2)), with: .color(grey(0.45)))
                    let markHalf: Double = row % ChartCodec.rowsPerBlock == 0 ? 14 : 4
                    for x in [frameX + 2, right - gutter + 2] {
                        notes.fill(Path(CGRect(x: x, y: barY - markHalf, width: gutter - 4, height: markHalf * 2)), with: .color(grey(0.85)))
                    }
                }
                for lane in 0..<8 where bits[row * 8 + lane] {
                    notes.fill(Path(CGRect(x: laneX0[lane] + 2, y: y - noteHeight / 2, width: laneWidths[lane] - 4, height: noteHeight)),
                               with: .color(noteColor(lane)))
                }
            }
        }
        fill(laneX0[0], laneX1(7), judgeY - 3, judgeY + 2, Color(red: 0.95, green: 0.12, blue: 0.1))
    }
}
