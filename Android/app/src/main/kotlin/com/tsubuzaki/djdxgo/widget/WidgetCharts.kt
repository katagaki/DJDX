package com.tsubuzaki.djdxgo.widget

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.DpSize
import com.tsubuzaki.djdxgo.data.RadarData
import com.tsubuzaki.djdxgo.ui.common.drawRadar
import kotlin.math.max
import kotlin.math.min

data class WidgetChartSegment(val color: Color, val value: Int)

data class WidgetChartSeries(val color: Color, val values: List<Int>)

object WidgetCharts {

    private const val MAX_SCALE = 2f

    private fun bitmap(size: DpSize, density: Float, draw: Canvas.(Float, Float, Float) -> Unit): Bitmap {
        val scale = min(density, MAX_SCALE)
        val width = max((size.width.value * scale).toInt(), 1)
        val height = max((size.height.value * scale).toInt(), 1)
        return Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).also {
            Canvas(it).draw(width.toFloat(), height.toFloat(), scale)
        }
    }

    private fun fill(color: Color) = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        this.color = color.toArgb()
    }

    fun pie(segments: List<WidgetChartSegment>, size: DpSize, density: Float): Bitmap =
        bitmap(size, density) { width, height, _ ->
            val total = segments.sumOf { it.value }.toFloat()
            if (total <= 0f) return@bitmap
            val diameter = min(width, height)
            val bounds = RectF(
                (width - diameter) / 2f, (height - diameter) / 2f,
                (width + diameter) / 2f, (height + diameter) / 2f
            )
            var start = -90f
            segments.forEach { segment ->
                val sweep = segment.value / total * 360f
                drawArc(bounds, start, sweep, true, fill(segment.color))
                start += sweep
            }
        }

    fun bars(segments: List<WidgetChartSegment>, size: DpSize, density: Float, spacing: Float = 4f): Bitmap =
        bitmap(size, density) { width, height, scale ->
            val maximum = segments.maxOfOrNull { it.value } ?: 0
            if (segments.isEmpty() || maximum <= 0) return@bitmap
            val gap = spacing * scale
            val barWidth = (width - gap * (segments.size - 1)) / segments.size
            val radius = min(barWidth / 4f, 6f * scale)
            segments.forEachIndexed { index, segment ->
                val barHeight = segment.value.toFloat() / maximum * height
                if (barHeight <= 0f) return@forEachIndexed
                val left = index * (barWidth + gap)
                val path = Path().apply {
                    addRoundRect(
                        RectF(left, height - barHeight, left + barWidth, height),
                        floatArrayOf(radius, radius, radius, radius, 0f, 0f, 0f, 0f),
                        Path.Direction.CW
                    )
                }
                drawPath(path, fill(segment.color))
            }
        }

    fun stackedArea(
        series: List<WidgetChartSeries>,
        dates: List<Long>,
        size: DpSize,
        density: Float
    ): Bitmap = bitmap(size, density) { width, height, _ ->
        if (dates.isEmpty() || series.isEmpty()) return@bitmap
        val points = if (dates.size == 1) listOf(0, 0) else dates.indices.toList()
        val totals = points.map { index -> series.sumOf { it.values[index] } }
        val maximum = totals.maxOrNull() ?: 0
        if (maximum <= 0) return@bitmap
        val firstDate = dates.first()
        val dateRange = (dates.last() - firstDate).coerceAtLeast(1L)
        val xs = if (dates.size == 1) {
            listOf(0f, width)
        } else {
            dates.map { (it - firstDate).toFloat() / dateRange * width }
        }
        val baseline = FloatArray(points.size)
        series.forEach { item ->
            val top = FloatArray(points.size) { baseline[it] + item.values[points[it]] }
            val path = Path()
            points.indices.forEach { index ->
                val y = height - top[index] / maximum * height
                if (index == 0) path.moveTo(xs[index], y) else path.lineTo(xs[index], y)
            }
            points.indices.reversed().forEach { index ->
                path.lineTo(xs[index], height - baseline[index] / maximum * height)
            }
            path.close()
            drawPath(path, fill(item.color))
            top.copyInto(baseline)
        }
    }

    fun radar(data: RadarData, color: Color, labelSize: Float, size: DpSize, density: Float): Bitmap =
        bitmap(size, density) { width, height, scale ->
            drawRadar(
                canvas = this,
                width = width,
                height = height,
                data = data,
                color = color,
                labelSizePx = labelSize * scale,
                labelTypeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD),
                lineWidthPx = 1.5f * scale,
                insetPx = labelSize * 2.5f * scale
            )
        }
}
