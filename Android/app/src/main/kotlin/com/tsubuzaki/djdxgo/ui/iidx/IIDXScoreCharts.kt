package com.tsubuzaki.djdxgo.ui.iidx

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import com.tsubuzaki.djdxgo.data.external.NotesRadarEntry
import com.tsubuzaki.djdxgo.ui.theme.Palette
import com.tsubuzaki.djdxgo.ui.theme.RadarColors
import kotlin.math.cos
import kotlin.math.sin

@Composable
fun IIDXScoreHistoryChart(
    scores: List<Int>,
    noteCount: Int?,
    modifier: Modifier = Modifier
) {
    val areaColor = Palette.blue
    Canvas(
        modifier = modifier
            .fillMaxWidth()
            .height(200.dp)
    ) {
        if (scores.size < 2) return@Canvas
        val maxScore = if (noteCount != null && noteCount > 0) {
            (noteCount * 2).toFloat()
        } else {
            scores.max().toFloat()
        }
        if (maxScore <= 0f) return@Canvas

        val stepX = size.width / (scores.size - 1).toFloat()
        fun yFor(score: Float): Float =
            size.height - (score / maxScore).coerceIn(0f, 1f) * size.height

        val guides = listOf(
            Triple(8f / 9f, Palette.orange, 0.7f),
            Triple(7f / 9f, Palette.gray, 0.55f),
            Triple(6f / 9f, Palette.teal, 0.4f)
        )
        guides.forEach { (fraction, color, alpha) ->
            val y = yFor(maxScore * fraction)
            drawLine(
                color = color.copy(alpha = alpha),
                start = Offset(0f, y),
                end = Offset(size.width, y),
                strokeWidth = 2f
            )
        }

        val linePath = Path()
        scores.forEachIndexed { index, score ->
            val x = index * stepX
            val y = yFor(score.toFloat())
            if (index == 0) linePath.moveTo(x, y) else linePath.lineTo(x, y)
        }
        val areaPath = Path().apply {
            addPath(linePath)
            lineTo(size.width, size.height)
            lineTo(0f, size.height)
            close()
        }
        drawPath(areaPath, areaColor.copy(alpha = 0.35f))
        drawPath(linePath, areaColor, style = Stroke(width = 4f))
    }
}

private data class RadarAxis(
    val label: String,
    val angle: Float,
    val color: Color,
    val value: Double
)

@Composable
fun IIDXNotesRadarChart(
    entry: NotesRadarEntry,
    modifier: Modifier = Modifier
) {
    val maxValue = 130.0
    val benchmarkValue = 100.0
    val polygonColor = RadarColors.polygonColor(entry.sum())
    val labelSizePx = with(LocalDensity.current) { 11.dp.toPx() }

    Canvas(
        modifier = modifier
            .fillMaxWidth()
            .height(220.dp)
    ) {
        val axes = listOf(
            RadarAxis("NOTES", (-Math.PI / 2).toFloat(), RadarColors.notes, entry.notes),
            RadarAxis("PEAK", (-Math.PI / 6).toFloat(), RadarColors.peak, entry.peak),
            RadarAxis("SCRATCH", (Math.PI / 6).toFloat(), RadarColors.scratch, entry.scratch),
            RadarAxis("SOF-LAN", (Math.PI / 2).toFloat(), RadarColors.soflan, entry.soflan),
            RadarAxis("CHARGE", (5 * Math.PI / 6).toFloat(), RadarColors.charge, entry.charge),
            RadarAxis("CHORD", (7 * Math.PI / 6).toFloat(), RadarColors.chord, entry.chord)
        )
        val center = Offset(size.width / 2f, size.height / 2f)
        val radius = (minOf(size.width, size.height) / 2f) - labelSizePx * 2f

        val benchmarkRadius = radius * (benchmarkValue / maxValue).toFloat()
        drawCircle(
            color = Color.Gray.copy(alpha = 0.3f),
            radius = benchmarkRadius,
            center = center
        )
        drawCircle(
            color = Color.Gray.copy(alpha = 0.7f),
            radius = benchmarkRadius,
            center = center,
            style = Stroke(width = 3f)
        )

        axes.forEach { axis ->
            drawLine(
                color = Color.Gray.copy(alpha = 0.4f),
                start = center,
                end = center + Offset(
                    radius * cos(axis.angle),
                    radius * sin(axis.angle)
                ),
                strokeWidth = 2f
            )
        }

        val polygon = Path()
        axes.forEachIndexed { index, axis ->
            val value = axis.value.coerceIn(0.0, maxValue)
            val pointRadius = radius * (value / maxValue).toFloat()
            val point = center + Offset(
                pointRadius * cos(axis.angle),
                pointRadius * sin(axis.angle)
            )
            if (index == 0) polygon.moveTo(point.x, point.y) else polygon.lineTo(point.x, point.y)
        }
        polygon.close()
        drawPath(polygon, polygonColor.copy(alpha = 0.4f))
        drawPath(polygon, polygonColor, style = Stroke(width = 4f))

        val paint = android.graphics.Paint().apply {
            textSize = labelSizePx
            isAntiAlias = true
            isFakeBoldText = true
            textAlign = android.graphics.Paint.Align.CENTER
        }
        axes.forEach { axis ->
            val tip = center + Offset(
                (radius + labelSizePx) * cos(axis.angle),
                (radius + labelSizePx) * sin(axis.angle)
            )
            paint.color = android.graphics.Color.argb(
                255,
                (axis.color.red * 255).toInt(),
                (axis.color.green * 255).toInt(),
                (axis.color.blue * 255).toInt()
            )
            drawContext.canvas.nativeCanvas.drawText(
                axis.label,
                tip.x,
                tip.y + labelSizePx / 3f,
                paint
            )
        }
    }
}
