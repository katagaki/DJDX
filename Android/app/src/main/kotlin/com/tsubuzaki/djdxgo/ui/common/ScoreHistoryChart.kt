package com.tsubuzaki.djdxgo.ui.common

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.ui.theme.Palette

data class HistoryGuide(val value: Float, val color: Color, val alpha: Float)

@Composable
fun HistoryLineChart(
    values: List<Float>,
    minValue: Float,
    maxValue: Float,
    modifier: Modifier = Modifier,
    color: Color = Palette.blue,
    guides: List<HistoryGuide> = emptyList()
) {
    Canvas(modifier = modifier.fillMaxWidth()) {
        val range = maxValue - minValue
        if (values.isEmpty() || range <= 0f) return@Canvas
        fun yFor(value: Float): Float =
            size.height - ((value - minValue) / range).coerceIn(0f, 1f) * size.height

        guides.filter { it.value in minValue..maxValue }.forEach { guide ->
            val y = yFor(guide.value)
            drawLine(
                color = guide.color.copy(alpha = guide.alpha),
                start = Offset(0f, y),
                end = Offset(size.width, y),
                strokeWidth = 2f
            )
        }

        if (values.size == 1) {
            drawCircle(color, radius = 6f, center = Offset(size.width / 2f, yFor(values[0])))
            return@Canvas
        }
        val stepX = size.width / (values.size - 1).toFloat()
        val linePath = Path()
        values.forEachIndexed { index, value ->
            val x = index * stepX
            val y = yFor(value)
            if (index == 0) linePath.moveTo(x, y) else linePath.lineTo(x, y)
        }
        val areaPath = Path().apply {
            addPath(linePath)
            lineTo(size.width, size.height)
            lineTo(0f, size.height)
            close()
        }
        drawPath(areaPath, color.copy(alpha = 0.35f))
        drawPath(linePath, color, style = Stroke(width = 4f))
    }
}

@Composable
fun ScoreHistoryCard(
    scores: List<Int>,
    minScore: Int,
    maxScore: Int,
    guides: List<HistoryGuide> = emptyList()
) {
    if (scores.size < 2) return
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainerHigh
        )
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text = stringResource(R.string.scores_viewer_history),
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold
            )
            HistoryLineChart(
                values = scores.map { it.toFloat() },
                minValue = minScore.toFloat(),
                maxValue = maxScore.toFloat(),
                guides = guides,
                modifier = Modifier.height(200.dp)
            )
        }
    }
}

fun zoomedHistoryMinimum(scores: List<Int>, step: Int, maxScore: Int): Int {
    val minimum = scores.minOrNull() ?: 0
    return ((minimum / step - 1) * step).coerceAtLeast(0).coerceAtMost(maxScore - step)
}
