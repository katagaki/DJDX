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
import com.tsubuzaki.djdxgo.ui.theme.Palette
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
