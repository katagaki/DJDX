import Foundation

extension IIDXChartProfile {

    static func isBuildUp(times: [Double]) -> Bool {
        guard let first = times.first, let last = times.last, last > first else { return false }
        let segmentCount = 12
        let segmentLength = (last - first) / Double(segmentCount)
        let densities = (0..<segmentCount).map { segment in
            let start = first + segmentLength * Double(segment)
            let end = segment == segmentCount - 1 ? last + 1e-9 : start + segmentLength
            return Double(lowerBound(times, end) - lowerBound(times, start)) / segmentLength
        }
        let positions = densities.indices.map(Double.init)
        let meanPosition = positions.reduce(0.0, +) / Double(segmentCount)
        let meanDensity = densities.reduce(0.0, +) / Double(segmentCount)
        guard meanDensity > 0.0, let finalDensity = densities.last else { return false }
        var covariance = 0.0
        var positionVariance = 0.0
        var densityVariance = 0.0
        for (position, density) in zip(positions, densities) {
            covariance += (position - meanPosition) * (density - meanDensity)
            positionVariance += (position - meanPosition) * (position - meanPosition)
            densityVariance += (density - meanDensity) * (density - meanDensity)
        }
        guard densityVariance > 0.0 else { return false }
        let rise = covariance / positionVariance * Double(segmentCount - 1) / meanDensity
        let correlation = covariance / (positionVariance * densityVariance).squareRoot()
        return rise >= 0.35 && correlation >= 0.6 && finalDensity >= meanDensity * 1.2
    }
}
