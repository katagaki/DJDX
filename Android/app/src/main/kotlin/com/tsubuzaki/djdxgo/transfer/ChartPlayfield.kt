package com.tsubuzaki.djdxgo.transfer

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.drawscope.withTransform

object ChartPlayfield {
    const val WIDTH = 390.0
    const val HEIGHT = 844.0
    val laneWidths = doubleArrayOf(54.0, 38.0, 32.0, 38.0, 32.0, 38.0, 32.0, 38.0)
    const val DIVIDER = 3.0
    const val GUTTER = 14.0
    val frameWidth = 2 * GUTTER + laneWidths.sum() + 9 * DIVIDER
    val frameX = (WIDTH - frameWidth) / 2
    val laneX0: DoubleArray = run {
        var x = frameX + GUTTER + DIVIDER
        DoubleArray(8) { lane -> x.also { x += laneWidths[lane] + DIVIDER } }
    }
    val leftGutterX = frameX + GUTTER / 2
    val rightGutterX = frameX + frameWidth - GUTTER / 2
    const val FRAME_TOP = 40.0
    const val VISIBLE_TOP = 64.0
    const val JUDGE_Y = 700.0
    const val FRAME_BOTTOM = 760.0
    const val PITCH = 112.0
    const val NOTE_HEIGHT = 14.0
    const val MEASURE = 8 * PITCH
    const val ROWS_PER_SECOND = 8.0
    const val SPEED = ROWS_PER_SECOND * PITCH
    const val FIDUCIAL_SIZE = 14.0
    val fiducials = listOf(
        leftGutterX to 50.0, rightGutterX to 50.0, rightGutterX to 742.0, leftGutterX to 742.0
    )

    fun laneX1(lane: Int): Double = laneX0[lane] + laneWidths[lane]

    fun noteColor(lane: Int): Color = when {
        lane == 0 -> Color(1.0f, 0.18f, 0.16f)
        lane % 2 == 1 -> Color(0.95f, 0.95f, 0.97f)
        else -> Color(0.22f, 0.48f, 1.0f)
    }

    fun fittedRect(size: Size): Rect {
        val scale = minOf(size.width / WIDTH.toFloat(), size.height / HEIGHT.toFloat())
        val width = WIDTH.toFloat() * scale
        val height = HEIGHT.toFloat() * scale
        return Rect(Offset((size.width - width) / 2, (size.height - height) / 2), Size(width, height))
    }

    private fun grey(value: Float) = Color(value, value, value)

    fun DrawScope.drawChart(bits: BooleanArray, time: Double) {
        drawRect(Color.Black)
        val rect = fittedRect(size)
        val scale = rect.width / WIDTH.toFloat()
        translate(rect.left, rect.top) {
            withTransform({ scale(scale, scale, Offset.Zero) }) {
                fun fill(x0: Double, x1: Double, y0: Double, y1: Double, color: Color) {
                    drawRect(color, Offset(x0.toFloat(), y0.toFloat()), Size((x1 - x0).toFloat(), (y1 - y0).toFloat()))
                }
                val right = frameX + frameWidth
                fill(frameX, frameX + GUTTER, FRAME_TOP, FRAME_BOTTOM, grey(0.035f))
                fill(right - GUTTER, right, FRAME_TOP, FRAME_BOTTOM, grey(0.035f))
                for (i in 0..8) {
                    val x = if (i < 8) laneX0[i] - DIVIDER else laneX1(7)
                    fill(x, x + DIVIDER, FRAME_TOP, FRAME_BOTTOM, grey(0.24f))
                }
                for (lane in 0 until 8) {
                    val x0 = laneX0[lane]
                    val x1 = laneX1(lane)
                    fill(x0, x1, FRAME_TOP, VISIBLE_TOP, grey(0.11f))
                    fill(x0, x1, VISIBLE_TOP, JUDGE_Y, if (lane == 0) Color(0.07f, 0.04f, 0.045f) else grey(0.05f))
                    when {
                        lane == 0 -> {
                            val center = Offset(((x0 + x1) / 2).toFloat(), 731f)
                            drawCircle(noteColor(0), 23f, center)
                            drawCircle(grey(0.12f), 20f, center)
                            drawCircle(grey(0.4f), 5f, center)
                        }
                        lane % 2 == 1 -> fill(x0 + 3, x1 - 3, 718.0, 756.0, grey(0.78f))
                        else -> fill(x0 + 3, x1 - 3, 708.0, 744.0, Color(0.14f, 0.28f, 0.7f))
                    }
                }
                val half = FIDUCIAL_SIZE / 2
                for ((x, y) in fiducials) fill(x - half, x + half, y - half, y + half, Color(0.12f, 0.95f, 0.3f))

                val rows = bits.size / 8
                if (rows > 0) {
                    clipRect(frameX.toFloat(), VISIBLE_TOP.toFloat(), right.toFloat(), JUDGE_Y.toFloat()) {
                        val offset = SPEED * time
                        val low = Math.floor((offset - PITCH) / PITCH).toInt()
                        val high = Math.ceil((JUDGE_Y + offset - VISIBLE_TOP + PITCH) / PITCH).toInt()
                        for (k in low..high) {
                            val y = JUDGE_Y - k * PITCH + offset
                            val row = Math.floorMod(k, rows)
                            if (row % 8 == 0) {
                                val barY = y + PITCH / 2
                                fill(laneX0[0], laneX1(7), barY - 1, barY + 1, grey(0.45f))
                                val markHalf = if (row % ChartCodec.ROWS_PER_BLOCK == 0) 14.0 else 4.0
                                for (x in listOf(frameX + 2, right - GUTTER + 2)) {
                                    fill(x, x + GUTTER - 4, barY - markHalf, barY + markHalf, grey(0.85f))
                                }
                            }
                            for (lane in 0 until 8) {
                                if (bits[row * 8 + lane]) {
                                    fill(laneX0[lane] + 2, laneX1(lane) - 2, y - NOTE_HEIGHT / 2, y + NOTE_HEIGHT / 2, noteColor(lane))
                                }
                            }
                        }
                    }
                }
                fill(laneX0[0], laneX1(7), JUDGE_Y - 3, JUDGE_Y + 2, Color(0.95f, 0.12f, 0.1f))
            }
        }
    }
}
