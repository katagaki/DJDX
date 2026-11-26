import CoreGraphics
import Foundation

struct ChartFrame: Sendable {
    let width: Int
    let height: Int
    var luma: [Float]
    var green: [Float]

    @inline(__always) func sample(_ x: Float, _ y: Float) -> Float {
        let fx = x - 0.5, fy = y - 0.5
        if fx < 0 || fy < 0 || fx >= Float(width - 1) || fy >= Float(height - 1) { return 0 }
        let x0 = Int(fx), y0 = Int(fy)
        let ax = fx - Float(x0), ay = fy - Float(y0)
        let i = y0 * width + x0
        return (luma[i] * (1 - ax) + luma[i + 1] * ax) * (1 - ay) + (luma[i + width] * (1 - ax) + luma[i + width + 1] * ax) * ay
    }
}

struct ChartHomography: Sendable {
    var m: [Double]

    static func fit(_ src: [CGPoint], _ dst: [CGPoint]) -> ChartHomography? {
        var a = [[Double]](repeating: [Double](repeating: 0, count: 9), count: 8)
        for i in 0..<4 {
            let x = Double(src[i].x), y = Double(src[i].y), u = Double(dst[i].x), v = Double(dst[i].y)
            a[2 * i] = [x, y, 1, 0, 0, 0, -u * x, -u * y, u]
            a[2 * i + 1] = [0, 0, 0, x, y, 1, -v * x, -v * y, v]
        }
        for col in 0..<8 {
            var pivot = col
            for r in col..<8 where abs(a[r][col]) > abs(a[pivot][col]) { pivot = r }
            if abs(a[pivot][col]) < 1e-12 { return nil }
            a.swapAt(col, pivot)
            for r in 0..<8 where r != col {
                let f = a[r][col] / a[col][col]
                if f != 0 { for c in col..<9 { a[r][c] -= f * a[col][c] } }
            }
        }
        return ChartHomography(m: (0..<8).map { a[$0][8] / a[$0][$0] } + [1])
    }

    @inline(__always) func apply(_ x: Double, _ y: Double) -> (Float, Float) {
        let w = m[6] * x + m[7] * y + m[8]
        return (Float((m[0] * x + m[1] * y + m[2]) / w), Float((m[3] * x + m[4] * y + m[5]) / w))
    }
}

struct ChartReceiveState: Sendable, Equatable {
    var corners: [CGPoint]?
    var frameSize: CGSize = .zero
    var hasLocked = false
    var blockCount: Int?
    var receivedBlocks: [Int] = []
    var message: [UInt8]?
}

final class ChartDecoder {
    private typealias P = ChartPlayfield
    private static let coastFor: Double = 1.1
    private static let relockAfter: Double = 1.2
    private static let resetAfterGap: Double = 5
    private static let maxSkew: Double = 48

    private var sums: [Int: [Float]] = [:]
    private var counts: [Int: [Float]] = [:]
    private var unwrapped: Double?
    private var lastTime: Double = 0
    private var speed = P.speed
    private var skew: Double = 0
    private var noBars = false
    private var recentPeaks: [Float] = []
    private var processed = 0
    private var oldestVisible = Int.min
    private var lowestRow = Int.max
    private var highestRow = Int.min
    private var blocks: [Int: [UInt8]] = [:]
    private var blockCount: Int?
    private var alignment: (start: Int, index: Int)?
    private(set) var state = ChartReceiveState()

    func process(_ frame: ChartFrame, time: Double) -> ChartReceiveState {
        state.frameSize = CGSize(width: frame.width, height: frame.height)
        state.corners = nil
        guard state.message == nil, let (h, corners) = findHomography(frame) else { return state }
        state.corners = corners
        if unwrapped != nil && time - lastTime > Self.resetAfterGap { resetTracking() }
        guard let phase = barPhase(frame, h, time: time) else {
            if noBars, let previous = unwrapped, time - lastTime < Self.coastFor {
                sampleCells(frame, h, previous + speed * (time - lastTime))
                processed += 1
                if processed % 2 == 0 { decode() }
            }
            return state
        }
        var u = phase
        if let previous = unwrapped {
            let elapsed = time - lastTime
            let predicted = previous + (elapsed > 1 ? P.speed : speed) * elapsed
            u = phase + P.measure * ((predicted - phase) / P.measure).rounded()
            if elapsed > 0 {
                let observed = (u - previous) / elapsed
                speed = max(P.speed * 0.9, min(P.speed * 1.1, 0.9 * speed + 0.1 * observed))
            }
        }
        unwrapped = u
        lastTime = time
        state.hasLocked = true
        sampleCells(frame, h, u)
        processed += 1
        if processed % 2 == 0 { decode() }
        return state
    }

    private func resetTracking() {
        unwrapped = nil
        speed = P.speed
        recentPeaks.removeAll()
        sums.removeAll()
        counts.removeAll()
        oldestVisible = Int.min
        lowestRow = Int.max
        highestRow = Int.min
        alignment = nil
    }

    private func findHomography(_ frame: ChartFrame) -> (ChartHomography, [CGPoint])? {
        let w = frame.width, h = frame.height, n = w * h
        var seen = [Bool](repeating: false, count: n)
        var blobs: [(x: Float, y: Float, area: Int)] = []
        var stack: [Int] = []
        for start in 0..<n where frame.green[start] > 0.15 && !seen[start] {
            stack.removeAll(keepingCapacity: true)
            stack.append(start)
            seen[start] = true
            var sx: Float = 0, sy: Float = 0, sw: Float = 0, area = 0
            while let i = stack.popLast() {
                let x = i % w, y = i / w, g = frame.green[i]
                sx += Float(x) * g; sy += Float(y) * g; sw += g; area += 1
                for next in [i - 1, i + 1, i - w, i + w]
                where next >= 0 && next < n && !seen[next] && frame.green[next] > 0.15 && abs(next % w - x) <= 1 {
                    seen[next] = true
                    stack.append(next)
                }
            }
            if area >= 3 && area <= 4000 { blobs.append((sx / sw + 0.5, sy / sw + 0.5, area)) }
        }
        guard blobs.count >= 4 else { return nil }
        let four = blobs.sorted { $0.area > $1.area }.prefix(4).sorted { $0.y < $1.y }
        let top = four.prefix(2).sorted { $0.x < $1.x }, bottom = four.suffix(2).sorted { $0.x < $1.x }
        let corners = [top[0], top[1], bottom[1], bottom[0]].map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
        var area: CGFloat = 0
        for i in 0..<4 {
            let a = corners[i], b = corners[(i + 1) % 4]
            area += a.x * b.y - b.x * a.y
        }
        guard abs(area) / 2 > CGFloat(n) * 0.04 else { return nil }
        guard let homography = ChartHomography.fit(P.fiducials, corners) else { return nil }
        return (homography, corners)
    }

    private func phase(_ y: Double) -> Double {
        let v = (y - P.judgeY - P.pitch / 2).truncatingRemainder(dividingBy: P.measure)
        return v < 0 ? v + P.measure : v
    }

    private func signed(_ a: Double, _ b: Double) -> Double {
        var d = a - b
        if d > P.measure / 2 { d -= P.measure }
        if d < -P.measure / 2 { d += P.measure }
        return d
    }

    private func barPhase(_ frame: ChartFrame, _ h: ChartHomography, time: Double) -> Double? {
        let y0 = Int(P.visibleTop) + 2, y1 = Int(P.judgeY) - 2, n = y1 - y0 + 1
        let window = 30
        func detrend(_ q: [Float]) -> [Float] {
            var d = [Float](repeating: 0, count: q.count)
            for i in q.indices {
                var low = Float.infinity
                for j in max(0, i - window)...min(q.count - 1, i + window) { low = min(low, q[j]) }
                d[i] = q[i] - low
            }
            return d
        }
        let half = skew / 2
        var left = [Float](repeating: 0, count: n), right = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let y = Double(y0 + i)
            var l: Float = 0, r: Float = 0
            for dx in [-3.0, 0, 3] {
                let (lx, ly) = h.apply(P.leftGutterX + dx, y - half)
                let (rx, ry) = h.apply(P.rightGutterX + dx, y + half)
                l += frame.sample(lx, ly)
                r += frame.sample(rx, ry)
            }
            left[i] = l / 3
            right[i] = r / 3
        }
        let d = detrend(zip(left, right).map { ($0 + $1) / 2 })
        let dl = detrend(left), dr = detrend(right)
        let threshold = max(0.08, 0.2 * (d.max() ?? 0))
        func sidePeak(_ q: [Float], _ y: Double) -> Float {
            let lower = max(0, Int((y - Double(y0) - Self.maxSkew).rounded()))
            let upper = min(n - 1, Int((y - Double(y0) + Self.maxSkew).rounded()))
            guard lower <= upper else { return 0 }
            return q[lower...upper].max() ?? 0
        }
        var regions: [(y: Double, peak: Float)] = []
        let minimumPeak = recentPeaks.count >= 4 ? recentPeaks.sorted()[recentPeaks.count * 3 / 10] * 0.45 : 0
        var i = 0
        while i < n {
            guard d[i] > threshold else {
                i += 1
                continue
            }
            var a = i, b = i
            while a > 0 && d[a - 1] > threshold / 2 { a -= 1 }
            while b < n - 1 && d[b + 1] > threshold / 2 { b += 1 }
            var area: Float = 0, moment: Float = 0, peak: Float = 0
            for k in a...b {
                area += d[k]
                moment += d[k] * Float(y0 + k)
                peak = max(peak, d[k])
            }
            let y = Double(moment / area)
            if a > 3 && b < n - 4 && peak >= minimumPeak && sidePeak(dl, y) > 0.5 * peak && sidePeak(dr, y) > 0.5 * peak {
                regions.append((y, peak))
            }
            i = b + 1
        }
        noBars = regions.isEmpty
        guard !regions.isEmpty else { return nil }
        if let previous = unwrapped, time - lastTime < Self.relockAfter {
            let predicted = phase(previous + speed * (time - lastTime) + P.judgeY + P.pitch / 2)
            regions = regions.filter { abs(signed(phase($0.y), predicted)) < 20 }
            if regions.isEmpty {
                noBars = true
                return nil
            }
        }
        let reference = regions.max { $0.peak < $1.peak }!
        let kept = regions.filter { abs(signed(phase($0.y), phase(reference.y))) < 8 }
        var result = phase(reference.y) + kept.map { signed(phase($0.y), phase(reference.y)) }.reduce(0, +) / Double(kept.count)
        if result < 0 { result += P.measure }
        recentPeaks.append(reference.peak)
        if recentPeaks.count > 24 { recentPeaks.removeFirst() }

        func centroid(_ q: [Float], _ y: Double) -> Double? {
            var area: Float = 0, moment: Float = 0
            let lower = max(0, Int((y - Double(y0) - Self.maxSkew).rounded()))
            let upper = min(n - 1, Int((y - Double(y0) + Self.maxSkew).rounded()))
            guard lower <= upper else { return nil }
            for k in lower...upper {
                let v = q[k] - threshold / 2
                if v > 0 {
                    area += v
                    moment += v * Float(y0 + k)
                }
            }
            return area > 0.05 ? Double(moment / area) : nil
        }
        for region in kept {
            if let yl = centroid(dl, region.y), let yr = centroid(dr, region.y) {
                skew = max(-Self.maxSkew, min(Self.maxSkew, skew + 0.25 * (yr - yl)))
            }
        }
        return result
    }

    private func sampleCells(_ frame: ChartFrame, _ h: ChartHomography, _ u0: Double) {
        let p = P.pitch
        let span = P.rightGutterX - P.leftGutterX
        oldestVisible = max(oldestVisible, Int(((u0 + 8) / p).rounded(.up)))
        func average(_ xs: [Double], _ y: Double) -> Float {
            var total: Float = 0
            for x in xs {
                let (cx, cy) = h.apply(x, y)
                total += frame.sample(cx, cy)
            }
            return total / Float(xs.count)
        }
        for lane in 0..<8 {
            let w = P.laneWidths[lane], center = P.laneX0[lane] + w / 2, spread = w * 0.25
            let xs = [center - spread, center, center + spread]
            let u = u0 + ((center - P.leftGutterX) / span - 0.5) * skew
            let low = Int(((u + 8) / p).rounded(.up)), high = Int(((P.judgeY + u - P.visibleTop - 8) / p).rounded(.down))
            guard low <= high else { continue }
            var values: [(k: Int, v: Float)] = []
            for k in low...high {
                let y = P.judgeY - Double(k) * p + u
                let note = (average(xs, y - 3) + average(xs, y) + average(xs, y + 3)) / 3
                let above = average(xs, y - 0.3 * p), below = average(xs, y + 0.3 * p)
                if max(above, below) > 0.8 { continue }
                values.append((k, note - min(above, below)))
            }
            guard values.count >= 4 else { continue }
            let sorted = values.map(\.v).sorted(by: >)
            let top = sorted.prefix(max(2, sorted.count / 4))
            let contrast = top.reduce(0, +) / Float(top.count)
            guard contrast > 0.06 else { continue }
            for (k, v) in values {
                let soft = max(-1, min(1, (v - contrast / 2) / (contrast / 2)))
                lowestRow = min(lowestRow, k)
                highestRow = max(highestRow, k)
                sums[k, default: [Float](repeating: 0, count: 8)][lane] += soft
                counts[k, default: [Float](repeating: 0, count: 8)][lane] += 1
            }
        }
    }

    private func grid(start: Int, period: Int?) -> (bits: [Bool], confidence: [Float]) {
        var bits = [Bool](repeating: false, count: 256), confidence = [Float](repeating: 0, count: 256)
        guard lowestRow <= highestRow else { return (bits, confidence) }
        for r in 0..<32 {
            var s = [Float](repeating: 0, count: 8), c = [Float](repeating: 0, count: 8)
            let row = start + r
            let step = period ?? Int.max
            var k = period.map { row - ((row - lowestRow) / $0) * $0 } ?? row
            while k <= highestRow {
                if let values = sums[k], let n = counts[k] {
                    for lane in 0..<8 {
                        s[lane] += values[lane]
                        c[lane] += n[lane]
                    }
                }
                if period == nil { break }
                k += step
            }
            for lane in 0..<8 {
                bits[r * 8 + lane] = s[lane] > 0
                confidence[r * 8 + lane] = c[lane] >= 3 ? abs(s[lane]) / c[lane] : 0
            }
        }
        return (bits, confidence)
    }

    private func accept(_ payload: [UInt8], start: Int?) {
        let count = ChartCodec.blockCount(payload), index = ChartCodec.blockIndex(payload)
        guard count >= 1, index < count, blockCount == nil || blockCount == count else { return }
        if alignment == nil, let start { alignment = (start, index) }
        guard blocks[index] == nil else { return }
        blockCount = count
        blocks[index] = payload
        state.blockCount = count
        state.receivedBlocks = blocks.keys.sorted()
        if let message = ChartCodec.assemble(blocks, count: count) { state.message = message }
    }

    private func decode() {
        if let count = blockCount, let alignment, blocks.count < count {
            let period = count * ChartCodec.rowsPerBlock
            for index in 0..<count where blocks[index] == nil {
                let start = alignment.start + (index - alignment.index) * ChartCodec.rowsPerBlock
                let g = grid(start: start, period: period)
                if let payload = ChartCodec.decodeBlock(bits: g.bits, confidence: g.confidence) { accept(payload, start: start) }
            }
            return
        }
        guard alignment == nil, oldestVisible != Int.min else { return }
        var start = Int((Double(oldestVisible - 64) / 8).rounded(.down)) * 8
        while start + 31 < oldestVisible {
            for period in [nil] + (1...ChartCodec.maxBlocks).map({ Optional($0 * ChartCodec.rowsPerBlock) }) {
                let g = grid(start: start, period: period)
                guard let payload = ChartCodec.decodeBlock(bits: g.bits, confidence: g.confidence) else { continue }
                let truePeriod = ChartCodec.blockCount(payload) * ChartCodec.rowsPerBlock
                let check = grid(start: start, period: truePeriod)
                let aligned = period == nil || period == truePeriod
                    || ChartCodec.decodeBlock(bits: check.bits, confidence: check.confidence) == payload
                accept(payload, start: aligned ? start : nil)
                if alignment != nil { return }
            }
            start += 8
        }
    }
}
