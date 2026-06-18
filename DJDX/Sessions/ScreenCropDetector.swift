import CoreImage
import UIKit
import Vision

enum ScreenCropDetector {

    struct Screen {
        var topLeft: CGPoint
        var topRight: CGPoint
        var bottomRight: CGPoint
        var bottomLeft: CGPoint

        var corners: [CGPoint] { [topLeft, topRight, bottomRight, bottomLeft] }
    }

    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - Public API

    static func detect(in imageData: Data) -> Screen? {
        guard let cgImage = uprightCGImage(from: imageData, maxDimension: 1024) else { return nil }
        guard let screen = brightScreen(in: cgImage), isPlausible(screen) else { return nil }
        return screen
    }

    static func perspectiveCorrect(imageData: Data, screen: Screen) -> Data? {
        guard let ciImage = CIImage(data: imageData, options: [.applyOrientationProperty: true]) else { return nil }
        let width = ciImage.extent.width, height = ciImage.extent.height
        func vector(_ point: CGPoint) -> CIVector {
            CIVector(x: min(max(point.x, 0), 1) * width, y: min(max(point.y, 0), 1) * height)
        }
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(vector(screen.topLeft), forKey: "inputTopLeft")
        filter.setValue(vector(screen.topRight), forKey: "inputTopRight")
        filter.setValue(vector(screen.bottomRight), forKey: "inputBottomRight")
        filter.setValue(vector(screen.bottomLeft), forKey: "inputBottomLeft")
        guard let output = filter.outputImage, !output.extent.isInfinite, !output.extent.isEmpty,
              let result = ciContext.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: result).jpegData(compressionQuality: 0.95)
    }

    // MARK: - Detection

    private static func brightScreen(in cgImage: CGImage) -> Screen? {
        guard let mask = brightMask(cgImage) else { return nil }
        let request = VNDetectContoursRequest()
        request.detectsDarkOnLight = false
        request.maximumImageDimension = 512
        let handler = VNImageRequestHandler(cgImage: mask)
        try? handler.perform([request])
        guard let observation = request.results?.first else { return nil }
        let largest = observation.topLevelContours.max { contourArea($0) < contourArea($1) }
        guard let largest, contourArea(largest) > 0.2,
              let raw = try? largest.normalizedPoints, raw.count >= 4 else { return nil }
        let hull = convexHull(raw.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) })
        guard !hull.isEmpty else { return nil }
        let angle = screenAngle(hull)
        if let quad = edgeFitQuad(hull, angle: angle), isValidQuad(quad) {
            return orderedScreen(quad)
        }
        return orderedScreen(orientedRect(hull, angle: angle))
    }

    private static func brightMask(_ cgImage: CGImage) -> CGImage? {
        let input = CIImage(cgImage: cgImage)
        guard let component = CIFilter(name: "CIMaximumComponent") else { return nil }
        component.setValue(input, forKey: kCIInputImageKey)
        guard var working = component.outputImage else { return nil }

        if let blur = CIFilter(name: "CIGaussianBlur") {
            blur.setValue(working, forKey: kCIInputImageKey)
            blur.setValue(min(input.extent.width, input.extent.height) * 0.02, forKey: kCIInputRadiusKey)
            if let blurred = blur.outputImage?.cropped(to: input.extent) { working = blurred }
        }

        guard let threshold = CIFilter(name: "CIColorThreshold") else { return nil }
        threshold.setValue(working, forKey: kCIInputImageKey)
        threshold.setValue(0.2, forKey: "inputThreshold")
        guard let output = threshold.outputImage?.cropped(to: input.extent) else { return nil }
        return ciContext.createCGImage(output, from: input.extent)
    }

    // MARK: - Quad fitting

    private static func screenAngle(_ hull: [CGPoint]) -> CGFloat {
        var bestArea = CGFloat.greatestFiniteMagnitude
        var bestRadians: CGFloat = 0
        var degrees: CGFloat = -20
        while degrees <= 20 {
            let radians = degrees * .pi / 180
            let axisX = cos(radians), axisY = sin(radians)
            var minU = CGFloat.greatestFiniteMagnitude, maxU = -CGFloat.greatestFiniteMagnitude
            var minV = CGFloat.greatestFiniteMagnitude, maxV = -CGFloat.greatestFiniteMagnitude
            for point in hull {
                let alongAxis = point.x * axisX + point.y * axisY
                let acrossAxis = -point.x * axisY + point.y * axisX
                minU = min(minU, alongAxis); maxU = max(maxU, alongAxis)
                minV = min(minV, acrossAxis); maxV = max(maxV, acrossAxis)
            }
            let area = (maxU - minU) * (maxV - minV)
            if area < bestArea { bestArea = area; bestRadians = radians }
            degrees += 0.5
        }
        return bestRadians
    }

    private static func orientedRect(_ hull: [CGPoint], angle radians: CGFloat) -> [CGPoint] {
        let axisX = cos(radians), axisY = sin(radians)
        var minU = CGFloat.greatestFiniteMagnitude, maxU = -CGFloat.greatestFiniteMagnitude
        var minV = CGFloat.greatestFiniteMagnitude, maxV = -CGFloat.greatestFiniteMagnitude
        for point in hull {
            let alongAxis = point.x * axisX + point.y * axisY
            let acrossAxis = -point.x * axisY + point.y * axisX
            minU = min(minU, alongAxis); maxU = max(maxU, alongAxis)
            minV = min(minV, acrossAxis); maxV = max(maxV, acrossAxis)
        }
        func toPoint(_ valueU: CGFloat, _ valueV: CGFloat) -> CGPoint {
            CGPoint(x: valueU * axisX - valueV * axisY, y: valueU * axisY + valueV * axisX)
        }
        return [toPoint(minU, minV), toPoint(maxU, minV), toPoint(maxU, maxV), toPoint(minU, maxV)]
    }

    private static func edgeFitQuad(_ hull: [CGPoint], angle radians: CGFloat) -> [CGPoint]? {
        let axisX = cos(radians), axisY = sin(radians)
        let projected = hull.map { ($0.x * axisX + $0.y * axisY, -$0.x * axisY + $0.y * axisX) }
        let minU = projected.map { $0.0 }.min()!, maxU = projected.map { $0.0 }.max()!
        let minV = projected.map { $0.1 }.min()!, maxV = projected.map { $0.1 }.max()!
        let bandU = 0.14 * (maxU - minU), bandV = 0.14 * (maxV - minV)
        let leftSamples = projected.filter { $0.0 - minU < bandU }.map { ($0.1, $0.0) }
        let rightSamples = projected.filter { maxU - $0.0 < bandU }.map { ($0.1, $0.0) }
        let topSamples = projected.filter { maxV - $0.1 < bandV }.map { ($0.0, $0.1) }
        let bottomSamples = projected.filter { $0.1 - minV < bandV }.map { ($0.0, $0.1) }
        guard let left = robustLine(leftSamples), let right = robustLine(rightSamples),
              let top = robustLine(topSamples), let bottom = robustLine(bottomSamples) else { return nil }

        func intersect(_ side: (slope: CGFloat, intercept: CGFloat),
                       _ edge: (slope: CGFloat, intercept: CGFloat)) -> CGPoint? {
            let denominator = 1 - edge.slope * side.slope
            guard abs(denominator) > 1e-6 else { return nil }
            let acrossAxis = (edge.slope * side.intercept + edge.intercept) / denominator
            let alongAxis = side.slope * acrossAxis + side.intercept
            return CGPoint(x: alongAxis * axisX - acrossAxis * axisY, y: alongAxis * axisY + acrossAxis * axisX)
        }
        guard let topLeft = intersect(left, top), let topRight = intersect(right, top),
              let bottomRight = intersect(right, bottom), let bottomLeft = intersect(left, bottom) else { return nil }
        return [topLeft, topRight, bottomRight, bottomLeft]
    }

    private static func robustLine(_ samples: [(CGFloat, CGFloat)]) -> (slope: CGFloat, intercept: CGFloat)? {
        func leastSquares(_ data: [(CGFloat, CGFloat)]) -> (slope: CGFloat, intercept: CGFloat)? {
            let count = CGFloat(data.count)
            guard count >= 2 else { return nil }
            let sumX = data.reduce(0) { $0 + $1.0 }, sumY = data.reduce(0) { $0 + $1.1 }
            let sumXX = data.reduce(0) { $0 + $1.0 * $1.0 }, sumXY = data.reduce(0) { $0 + $1.0 * $1.1 }
            let denominator = count * sumXX - sumX * sumX
            guard abs(denominator) > 1e-9 else { return nil }
            let slope = (count * sumXY - sumX * sumY) / denominator
            return (slope, (sumY - slope * sumX) / count)
        }
        guard let initial = leastSquares(samples) else { return nil }
        let residuals = samples.map { abs($0.1 - (initial.slope * $0.0 + initial.intercept)) }
        let meanResidual = residuals.reduce(0, +) / CGFloat(residuals.count)
        let kept = samples.enumerated().filter { residuals[$0.offset] <= 2 * meanResidual + 1e-6 }.map { $0.element }
        return leastSquares(kept.count >= 2 ? kept : samples)
    }

    // MARK: - Geometry

    private static func convexHull(_ points: [CGPoint]) -> [CGPoint] {
        let sorted = points.sorted { $0.x < $1.x || ($0.x == $1.x && $0.y < $1.y) }
        guard sorted.count >= 3 else { return sorted }
        func cross(_ origin: CGPoint, _ first: CGPoint, _ second: CGPoint) -> CGFloat {
            (first.x - origin.x) * (second.y - origin.y) - (first.y - origin.y) * (second.x - origin.x)
        }
        var lower: [CGPoint] = []
        for point in sorted {
            while lower.count >= 2, cross(lower[lower.count - 2], lower[lower.count - 1], point) <= 0 { lower.removeLast() }
            lower.append(point)
        }
        var upper: [CGPoint] = []
        for point in sorted.reversed() {
            while upper.count >= 2, cross(upper[upper.count - 2], upper[upper.count - 1], point) <= 0 { upper.removeLast() }
            upper.append(point)
        }
        lower.removeLast()
        upper.removeLast()
        return lower + upper
    }

    private static func orderedScreen(_ points: [CGPoint]) -> Screen {
        var topLeft = points[0], topRight = points[0], bottomRight = points[0], bottomLeft = points[0]
        for point in points {
            if point.x - point.y < topLeft.x - topLeft.y { topLeft = point }
            if point.x + point.y > topRight.x + topRight.y { topRight = point }
            if point.x - point.y > bottomRight.x - bottomRight.y { bottomRight = point }
            if point.x + point.y < bottomLeft.x + bottomLeft.y { bottomLeft = point }
        }
        return Screen(topLeft: topLeft, topRight: topRight, bottomRight: bottomRight, bottomLeft: bottomLeft)
    }

    private static func isValidQuad(_ corners: [CGPoint]) -> Bool {
        guard corners.count == 4 else { return false }
        guard corners.allSatisfy({ $0.x > -0.3 && $0.x < 1.3 && $0.y > -0.3 && $0.y < 1.3 }) else { return false }
        let area = polygonArea(corners)
        guard area > 0.25, area < 1.05 else { return false }
        var sign = 0
        for index in 0..<4 {
            let first = corners[index], second = corners[(index + 1) % 4], third = corners[(index + 2) % 4]
            let cross = (second.x - first.x) * (third.y - second.y) - (second.y - first.y) * (third.x - second.x)
            let current = cross > 0 ? 1 : (cross < 0 ? -1 : 0)
            if current != 0 {
                if sign == 0 { sign = current } else if current != sign { return false }
            }
        }
        return true
    }

    private static func isPlausible(_ screen: Screen) -> Bool {
        let points = screen.corners
        guard points.allSatisfy({ $0.x > -0.3 && $0.x < 1.3 && $0.y > -0.3 && $0.y < 1.3 }) else { return false }
        return polygonArea(points) > 0.18
    }

    private static func polygonArea(_ points: [CGPoint]) -> CGFloat {
        guard points.count >= 3 else { return 0 }
        var sum: CGFloat = 0
        for index in points.indices {
            let current = points[index], next = points[(index + 1) % points.count]
            sum += current.x * next.y - next.x * current.y
        }
        return abs(sum) / 2
    }

    private static func contourArea(_ contour: VNContour) -> CGFloat {
        guard let points = try? contour.normalizedPoints else { return 0 }
        return polygonArea(points.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) })
    }

    // MARK: - Image processing

    private static func uprightCGImage(from data: Data, maxDimension: CGFloat) -> CGImage? {
        guard let image = UIImage(data: data) else { return nil }
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1.0)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }.cgImage
    }
}
