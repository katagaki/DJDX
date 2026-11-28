import SwiftUI

struct RadarChartView: View {
    let color: Color
    let points: [RadarPointConfig]
    var comparisonPoints: [RadarPointConfig]?
    let maxValue: Double = 130.0
    let benchmarkValue: Double = 100.0
    var labelFontSize: CGFloat = 12.0
    var lineWidth: CGFloat = 2.0
    var labelPadding: CGFloat = 30.0

    init(_ data: RadarData, isPlayerRadar: Bool = false, comparison: RadarData? = nil,
         labelFontSize: CGFloat = 12.0, lineWidth: CGFloat = 2.0, labelPadding: CGFloat = 30.0) {
        self.color = data.color(isPlayerRadar: isPlayerRadar)
        self.points = data.points()
        self.comparisonPoints = comparison?.points()
        self.labelFontSize = labelFontSize
        self.lineWidth = lineWidth
        self.labelPadding = labelPadding
    }

    init(_ data: RadarData, color: Color, labelFontSize: CGFloat = 12.0, lineWidth: CGFloat = 2.0,
         labelPadding: CGFloat = 30.0) {
        self.color = color
        self.points = data.points()
        self.labelFontSize = labelFontSize
        self.lineWidth = lineWidth
        self.labelPadding = labelPadding
    }

    var body: some View {
        GeometryReader { geometry in
            let size = max(0.0, min(geometry.size.width - labelPadding, geometry.size.height - labelPadding))
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = size / 2
            let circleScale = benchmarkValue / maxValue
            let circleSize = size * CGFloat(circleScale)

            let circleLineWidth = min(2.0, lineWidth)
            let axisLineWidth: CGFloat = lineWidth < 1.5 ? 0.5 : 1.0
            let axisDash: CGFloat = lineWidth < 1.5 ? 2.0 : 4.0

            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.5))
                    .stroke(Color.gray.opacity(0.8), lineWidth: circleLineWidth)
                    .frame(width: circleSize, height: circleSize)

                RadarAxesShape(configs: points)
                    .stroke(Color.gray.opacity(0.4), style: StrokeStyle(lineWidth: axisLineWidth, dash: [axisDash]))
                    .frame(width: size, height: size)

                ForEach(0..<points.count, id: \.self) { index in
                    let config = points[index]
                    let tipX = center.x + radius * CGFloat(cos(config.angle))
                    let tipY = center.y + radius * CGFloat(sin(config.angle))

                    Color.clear
                        .frame(width: 0, height: 0)
                        .overlay(
                            Text(config.label)
                                .font(.radarline(size: labelFontSize))
                                .radarLabelStyle(config.color)
                                .fixedSize(),
                            alignment: config.alignment
                        )
                        .position(x: tipX, y: tipY)
                }

                ZStack {
                    if let comparisonPoints {
                        RadarPolygonShape(configs: comparisonPoints, maxValue: maxValue)
                            .stroke(Color.primary.opacity(0.6), style: StrokeStyle(lineWidth: lineWidth, dash: [3]))
                    }
                    RadarPolygonShape(configs: points, maxValue: maxValue)
                        .fill(color.opacity(0.5))
                    RadarPolygonShape(configs: points, maxValue: maxValue)
                        .stroke(color, lineWidth: lineWidth)
                }
                .frame(width: size, height: size)
            }
        }
    }
}
