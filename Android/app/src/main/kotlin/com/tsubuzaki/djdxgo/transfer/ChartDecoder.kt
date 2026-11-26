package com.tsubuzaki.djdxgo.transfer

import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.floor

class ChartFrame(val width: Int, val height: Int, val luma: FloatArray, val green: FloatArray) {
    fun sample(x: Float, y: Float): Float {
        val fx = x - 0.5f
        val fy = y - 0.5f
        if (fx < 0 || fy < 0 || fx >= width - 1 || fy >= height - 1) return 0f
        val x0 = fx.toInt()
        val y0 = fy.toInt()
        val ax = fx - x0
        val ay = fy - y0
        val i = y0 * width + x0
        return (luma[i] * (1 - ax) + luma[i + 1] * ax) * (1 - ay) + (luma[i + width] * (1 - ax) + luma[i + width + 1] * ax) * ay
    }
}

class ChartHomography(private val m: DoubleArray) {
    fun apply(x: Double, y: Double): Pair<Float, Float> {
        val w = m[6] * x + m[7] * y + m[8]
        return ((m[0] * x + m[1] * y + m[2]) / w).toFloat() to ((m[3] * x + m[4] * y + m[5]) / w).toFloat()
    }

    companion object {
        fun fit(src: List<Pair<Double, Double>>, dst: List<Pair<Double, Double>>): ChartHomography? {
            val a = Array(8) { DoubleArray(9) }
            for (i in 0 until 4) {
                val (x, y) = src[i]
                val (u, v) = dst[i]
                a[2 * i] = doubleArrayOf(x, y, 1.0, 0.0, 0.0, 0.0, -u * x, -u * y, u)
                a[2 * i + 1] = doubleArrayOf(0.0, 0.0, 0.0, x, y, 1.0, -v * x, -v * y, v)
            }
            for (col in 0 until 8) {
                var pivot = col
                for (r in col until 8) if (abs(a[r][col]) > abs(a[pivot][col])) pivot = r
                if (abs(a[pivot][col]) < 1e-12) return null
                val swap = a[col]; a[col] = a[pivot]; a[pivot] = swap
                for (r in 0 until 8) {
                    if (r == col) continue
                    val f = a[r][col] / a[col][col]
                    if (f != 0.0) for (c in col until 9) a[r][c] -= f * a[col][c]
                }
            }
            return ChartHomography(DoubleArray(9) { if (it < 8) a[it][8] / a[it][it] else 1.0 })
        }
    }
}

data class ChartReceiveState(
    val corners: List<Pair<Float, Float>>? = null,
    val frameWidth: Int = 0,
    val frameHeight: Int = 0,
    val hasLocked: Boolean = false,
    val blockCount: Int? = null,
    val receivedBlocks: Set<Int> = emptySet(),
    val message: ByteArray? = null
)

class ChartDecoder {
    private val p = ChartPlayfield
    private val sums = HashMap<Int, FloatArray>()
    private val counts = HashMap<Int, FloatArray>()
    private var unwrapped: Double? = null
    private var lastTime = 0.0
    private var speed = ChartPlayfield.SPEED
    private var skew = 0.0
    private var noBars = false
    private val recentPeaks = ArrayDeque<Float>()
    private var processed = 0
    private var oldestVisible = Int.MIN_VALUE
    private var lowestRow = Int.MAX_VALUE
    private var highestRow = Int.MIN_VALUE
    private val blocks = HashMap<Int, IntArray>()
    private var blockCount: Int? = null
    private var alignment: Pair<Int, Int>? = null
    var state = ChartReceiveState()
        private set

    fun process(frame: ChartFrame, time: Double): ChartReceiveState {
        state = state.copy(frameWidth = frame.width, frameHeight = frame.height, corners = null)
        if (state.message != null) return state
        val (h, corners) = findHomography(frame) ?: return state
        state = state.copy(corners = corners)
        if (unwrapped != null && time - lastTime > RESET_AFTER_GAP) resetTracking()
        val phase = barPhase(frame, h, time) ?: run {
            val previous = unwrapped
            if (noBars && previous != null && time - lastTime < COAST_FOR) {
                sampleCells(frame, h, previous + speed * (time - lastTime))
                processed++
                if (processed % 2 == 0) decode()
            }
            return state
        }
        var u: Double = phase
        unwrapped?.let { previous ->
            val elapsed = time - lastTime
            val predicted = previous + (if (elapsed > 1) p.SPEED else speed) * elapsed
            u = phase + p.MEASURE * Math.rint((predicted - phase) / p.MEASURE)
            if (elapsed > 0) {
                val observed = (u - previous) / elapsed
                speed = (0.9 * speed + 0.1 * observed).coerceIn(p.SPEED * 0.9, p.SPEED * 1.1)
            }
        }
        unwrapped = u
        lastTime = time
        state = state.copy(hasLocked = true)
        sampleCells(frame, h, u)
        processed++
        if (processed % 2 == 0) decode()
        return state
    }

    private fun resetTracking() {
        unwrapped = null
        speed = p.SPEED
        recentPeaks.clear()
        sums.clear()
        counts.clear()
        oldestVisible = Int.MIN_VALUE
        lowestRow = Int.MAX_VALUE
        highestRow = Int.MIN_VALUE
        alignment = null
    }

    private fun findHomography(frame: ChartFrame): Pair<ChartHomography, List<Pair<Float, Float>>>? {
        val w = frame.width
        val n = w * frame.height
        val seen = BooleanArray(n)
        val blobs = ArrayList<Triple<Float, Float, Int>>()
        val stack = IntArray(n)
        for (start in 0 until n) {
            if (frame.green[start] <= 0.15f || seen[start]) continue
            var top = 0
            stack[top++] = start
            seen[start] = true
            var sx = 0f; var sy = 0f; var sw = 0f; var area = 0
            while (top > 0) {
                val i = stack[--top]
                val x = i % w
                val g = frame.green[i]
                sx += x * g; sy += (i / w) * g; sw += g; area += 1
                for (next in intArrayOf(i - 1, i + 1, i - w, i + w)) {
                    if (next < 0 || next >= n || seen[next] || frame.green[next] <= 0.15f || abs(next % w - x) > 1) continue
                    seen[next] = true
                    stack[top++] = next
                }
            }
            if (area in 3..4000) blobs += Triple(sx / sw + 0.5f, sy / sw + 0.5f, area)
        }
        if (blobs.size < 4) return null
        val four = blobs.sortedByDescending { it.third }.take(4).sortedBy { it.second }
        val upper = four.take(2).sortedBy { it.first }
        val lower = four.drop(2).sortedBy { it.first }
        val corners = listOf(upper[0], upper[1], lower[1], lower[0]).map { it.first to it.second }
        var area = 0f
        for (i in 0 until 4) {
            val a = corners[i]
            val b = corners[(i + 1) % 4]
            area += a.first * b.second - b.first * a.second
        }
        if (abs(area) / 2 <= n * 0.04f) return null
        val homography = ChartHomography.fit(
            p.fiducials, corners.map { it.first.toDouble() to it.second.toDouble() }
        ) ?: return null
        return homography to corners
    }

    private fun phase(y: Double): Double {
        val v = (y - p.JUDGE_Y - p.PITCH / 2) % p.MEASURE
        return if (v < 0) v + p.MEASURE else v
    }

    private fun signed(a: Double, b: Double): Double {
        var d = a - b
        if (d > p.MEASURE / 2) d -= p.MEASURE
        if (d < -p.MEASURE / 2) d += p.MEASURE
        return d
    }

    private fun detrend(q: FloatArray): FloatArray = FloatArray(q.size) { i ->
        var low = Float.MAX_VALUE
        for (j in maxOf(0, i - 30)..minOf(q.size - 1, i + 30)) low = minOf(low, q[j])
        q[i] - low
    }

    private fun barPhase(frame: ChartFrame, h: ChartHomography, time: Double): Double? {
        val y0 = p.VISIBLE_TOP.toInt() + 2
        val y1 = p.JUDGE_Y.toInt() - 2
        val n = y1 - y0 + 1
        val half = skew / 2
        val left = FloatArray(n)
        val right = FloatArray(n)
        for (i in 0 until n) {
            val y = (y0 + i).toDouble()
            var l = 0f
            var r = 0f
            for (dx in doubleArrayOf(-3.0, 0.0, 3.0)) {
                val (lx, ly) = h.apply(p.leftGutterX + dx, y - half)
                val (rx, ry) = h.apply(p.rightGutterX + dx, y + half)
                l += frame.sample(lx, ly)
                r += frame.sample(rx, ry)
            }
            left[i] = l / 3
            right[i] = r / 3
        }
        val d = detrend(FloatArray(n) { (left[it] + right[it]) / 2 })
        val dl = detrend(left)
        val dr = detrend(right)
        val threshold = maxOf(0.08f, 0.2f * (d.maxOrNull() ?: 0f))
        fun window(y: Double): IntRange =
            maxOf(0, Math.round(y - y0 - MAX_SKEW).toInt())..minOf(n - 1, Math.round(y - y0 + MAX_SKEW).toInt())
        fun sidePeak(q: FloatArray, y: Double): Float = window(y).maxOfOrNull { q[it] } ?: 0f
        val minimumPeak = if (recentPeaks.size >= 4) recentPeaks.sorted()[recentPeaks.size * 3 / 10] * 0.45f else 0f
        var regions = ArrayList<Pair<Double, Float>>()
        var i = 0
        while (i < n) {
            if (d[i] <= threshold) {
                i++
                continue
            }
            var a = i
            var b = i
            while (a > 0 && d[a - 1] > threshold / 2) a--
            while (b < n - 1 && d[b + 1] > threshold / 2) b++
            var area = 0f
            var moment = 0f
            var peak = 0f
            for (k in a..b) {
                area += d[k]
                moment += d[k] * (y0 + k)
                peak = maxOf(peak, d[k])
            }
            val y = (moment / area).toDouble()
            if (a > 3 && b < n - 4 && peak >= minimumPeak && sidePeak(dl, y) > 0.5f * peak && sidePeak(dr, y) > 0.5f * peak) {
                regions += y to peak
            }
            i = b + 1
        }
        noBars = regions.isEmpty()
        if (regions.isEmpty()) return null
        val previous = unwrapped
        if (previous != null && time - lastTime < RELOCK_AFTER) {
            val predicted = phase(previous + speed * (time - lastTime) + p.JUDGE_Y + p.PITCH / 2)
            regions = ArrayList(regions.filter { abs(signed(phase(it.first), predicted)) < 20 })
            if (regions.isEmpty()) {
                noBars = true
                return null
            }
        }
        val reference = regions.maxBy { it.second }
        val kept = regions.filter { abs(signed(phase(it.first), phase(reference.first))) < 8 }
        var result = phase(reference.first) + kept.sumOf { signed(phase(it.first), phase(reference.first)) } / kept.size
        if (result < 0) result += p.MEASURE
        recentPeaks.addLast(reference.second)
        if (recentPeaks.size > 24) recentPeaks.removeFirst()
        fun centroid(q: FloatArray, y: Double): Double? {
            var area = 0f
            var moment = 0f
            for (k in window(y)) {
                val v = q[k] - threshold / 2
                if (v > 0) {
                    area += v
                    moment += v * (y0 + k)
                }
            }
            return if (area > 0.05f) (moment / area).toDouble() else null
        }
        for ((y, _) in kept) {
            val yl = centroid(dl, y) ?: continue
            val yr = centroid(dr, y) ?: continue
            skew = (skew + 0.25 * (yr - yl)).coerceIn(-MAX_SKEW, MAX_SKEW)
        }
        return result
    }

    private fun sampleCells(frame: ChartFrame, h: ChartHomography, u0: Double) {
        val span = p.rightGutterX - p.leftGutterX
        oldestVisible = maxOf(oldestVisible, ceil((u0 + 8) / p.PITCH).toInt())
        fun average(xs: DoubleArray, y: Double): Float {
            var total = 0f
            for (x in xs) {
                val (cx, cy) = h.apply(x, y)
                total += frame.sample(cx, cy)
            }
            return total / xs.size
        }
        for (lane in 0 until 8) {
            val w = p.laneWidths[lane]
            val center = p.laneX0[lane] + w / 2
            val spread = w * 0.25
            val xs = doubleArrayOf(center - spread, center, center + spread)
            val u = u0 + ((center - p.leftGutterX) / span - 0.5) * skew
            val low = ceil((u + 8) / p.PITCH).toInt()
            val high = floor((p.JUDGE_Y + u - p.VISIBLE_TOP - 8) / p.PITCH).toInt()
            if (low > high) continue
            val values = ArrayList<Pair<Int, Float>>()
            for (k in low..high) {
                val y = p.JUDGE_Y - k * p.PITCH + u
                val note = (average(xs, y - 3) + average(xs, y) + average(xs, y + 3)) / 3
                val above = average(xs, y - 0.3 * p.PITCH)
                val below = average(xs, y + 0.3 * p.PITCH)
                if (maxOf(above, below) > 0.8f) continue
                values += k to note - minOf(above, below)
            }
            if (values.size < 4) continue
            val sorted = values.map { it.second }.sortedDescending()
            val top = sorted.take(maxOf(2, sorted.size / 4))
            val contrast = top.sum() / top.size
            if (contrast <= 0.06f) continue
            for ((k, v) in values) {
                val soft = ((v - contrast / 2) / (contrast / 2)).coerceIn(-1f, 1f)
                lowestRow = minOf(lowestRow, k)
                highestRow = maxOf(highestRow, k)
                sums.getOrPut(k) { FloatArray(8) }[lane] += soft
                counts.getOrPut(k) { FloatArray(8) }[lane] += 1f
            }
        }
    }

    private fun grid(start: Int, period: Int?): Pair<BooleanArray, FloatArray> {
        val bits = BooleanArray(256)
        val confidence = FloatArray(256)
        if (lowestRow > highestRow) return bits to confidence
        for (r in 0 until 32) {
            val s = FloatArray(8)
            val c = FloatArray(8)
            val row = start + r
            var k = if (period != null) row - Math.floorDiv(row - lowestRow, period) * period else row
            while (k <= highestRow) {
                val values = sums[k]
                val n = counts[k]
                if (values != null && n != null) {
                    for (lane in 0 until 8) {
                        s[lane] += values[lane]
                        c[lane] += n[lane]
                    }
                }
                if (period == null) break
                k += period
            }
            for (lane in 0 until 8) {
                bits[r * 8 + lane] = s[lane] > 0
                confidence[r * 8 + lane] = if (c[lane] >= 3) abs(s[lane]) / c[lane] else 0f
            }
        }
        return bits to confidence
    }

    private fun accept(payload: IntArray, start: Int?) {
        val count = ChartCodec.blockCount(payload)
        val index = ChartCodec.blockIndex(payload)
        if (count < 1 || index >= count || (blockCount != null && blockCount != count)) return
        if (alignment == null && start != null) alignment = start to index
        if (blocks.containsKey(index)) return
        blockCount = count
        blocks[index] = payload
        state = state.copy(blockCount = count, receivedBlocks = blocks.keys.toSet(), message = ChartCodec.assemble(blocks, count))
    }

    private fun decode() {
        val count = blockCount
        val aligned = alignment
        if (count != null && aligned != null && blocks.size < count) {
            val period = count * ChartCodec.ROWS_PER_BLOCK
            for (index in 0 until count) {
                if (blocks.containsKey(index)) continue
                val start = aligned.first + (index - aligned.second) * ChartCodec.ROWS_PER_BLOCK
                val (bits, confidence) = grid(start, period)
                ChartCodec.decodeBlock(bits, confidence)?.let { accept(it, start) }
            }
            return
        }
        if (aligned != null || oldestVisible == Int.MIN_VALUE) return
        var start = Math.floorDiv(oldestVisible - 64, 8) * 8
        val periods = listOf<Int?>(null) + (1..ChartCodec.MAX_BLOCKS).map { it * ChartCodec.ROWS_PER_BLOCK }
        while (start + 31 < oldestVisible) {
            for (period in periods) {
                val (bits, confidence) = grid(start, period)
                val payload = ChartCodec.decodeBlock(bits, confidence) ?: continue
                val truePeriod = ChartCodec.blockCount(payload) * ChartCodec.ROWS_PER_BLOCK
                val aligns = period == null || period == truePeriod ||
                    grid(start, truePeriod).let { (b, c) -> ChartCodec.decodeBlock(b, c)?.contentEquals(payload) == true }
                accept(payload, if (aligns) start else null)
                if (alignment != null) return
            }
            start += 8
        }
    }

    private companion object {
        const val COAST_FOR = 1.1
        const val RELOCK_AFTER = 1.2
        const val RESET_AFTER_GAP = 5.0
        const val MAX_SKEW = 48.0
    }
}
