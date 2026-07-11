package com.tsubuzaki.djdxgo.ui.analytics

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import kotlin.math.max
import kotlin.math.min

internal data class StackedSegment(val key: String, val count: Int, val color: Color)

internal data class StackedRow(val label: String, val segments: List<StackedSegment>)

@Composable
internal fun AnalyticsCard(
    title: String,
    icon: ImageVector,
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit
) {
    val shape = RoundedCornerShape(16.dp)
    if (onClick != null) {
        ElevatedCard(onClick = onClick, modifier = modifier, shape = shape) {
            AnalyticsCardBody(title, icon, content)
        }
    } else {
        ElevatedCard(modifier = modifier, shape = shape) {
            AnalyticsCardBody(title, icon, content)
        }
    }
}

@Composable
private fun AnalyticsCardBody(
    title: String,
    icon: ImageVector,
    content: @Composable ColumnScope.() -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(20.dp)
            )
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurface
            )
        }
        content()
    }
}

@Composable
internal fun HorizontalBarChart(
    entries: List<Pair<String, Int>>,
    colorFor: (String) -> Color,
    modifier: Modifier = Modifier
) {
    if (entries.isEmpty()) return
    val textMeasurer = rememberTextMeasurer()
    val labelStyle = MaterialTheme.typography.labelSmall
        .copy(color = MaterialTheme.colorScheme.onSurfaceVariant)
    val countStyle = MaterialTheme.typography.labelSmall
        .copy(color = MaterialTheme.colorScheme.onSurface)
    val rowHeight = 24.dp
    Canvas(
        modifier = modifier
            .fillMaxWidth()
            .height(rowHeight * entries.size)
    ) {
        val rowPx = rowHeight.toPx()
        val barPx = 14.dp.toPx()
        val gapPx = 6.dp.toPx()
        val maxCount = entries.maxOf { it.second }.coerceAtLeast(1)
        val labelWidth = entries.maxOf {
            textMeasurer.measure(it.first, labelStyle).size.width
        } + gapPx * 2f
        val maxCountWidth = entries.maxOf {
            textMeasurer.measure(it.second.toString(), countStyle).size.width
        }
        val available = (size.width - labelWidth - maxCountWidth - gapPx).coerceAtLeast(1f)
        entries.forEachIndexed { index, (label, count) ->
            val top = index * rowPx
            val labelLayout = textMeasurer.measure(label, labelStyle)
            drawText(
                textLayoutResult = labelLayout,
                topLeft = Offset(0f, top + (rowPx - labelLayout.size.height) / 2f)
            )
            val barWidth = if (count > 0) {
                (count.toFloat() / maxCount * available).coerceAtLeast(barPx / 2f)
            } else {
                0f
            }
            if (barWidth > 0f) {
                drawRoundRect(
                    color = colorFor(label),
                    topLeft = Offset(labelWidth, top + (rowPx - barPx) / 2f),
                    size = Size(barWidth, barPx),
                    cornerRadius = CornerRadius(barPx / 2f)
                )
            }
            val countLayout = textMeasurer.measure(count.toString(), countStyle)
            drawText(
                textLayoutResult = countLayout,
                topLeft = Offset(
                    labelWidth + barWidth + gapPx,
                    top + (rowPx - countLayout.size.height) / 2f
                )
            )
        }
    }
}

@Composable
internal fun StackedBarChart(
    rows: List<StackedRow>,
    modifier: Modifier = Modifier
) {
    if (rows.isEmpty()) return
    val textMeasurer = rememberTextMeasurer()
    val labelStyle = MaterialTheme.typography.labelSmall
        .copy(color = MaterialTheme.colorScheme.onSurfaceVariant)
    val rowHeight = 22.dp
    Canvas(
        modifier = modifier
            .fillMaxWidth()
            .height(rowHeight * rows.size)
    ) {
        val rowPx = rowHeight.toPx()
        val barPx = 14.dp.toPx()
        val gapPx = 6.dp.toPx()
        val maxTotal = rows.maxOf { row -> row.segments.sumOf { it.count } }.coerceAtLeast(1)
        val labelWidth = rows.maxOf {
            textMeasurer.measure(it.label, labelStyle).size.width
        } + gapPx * 2f
        val available = (size.width - labelWidth).coerceAtLeast(1f)
        rows.forEachIndexed { index, row ->
            val top = index * rowPx
            val labelLayout = textMeasurer.measure(row.label, labelStyle)
            drawText(
                textLayoutResult = labelLayout,
                topLeft = Offset(0f, top + (rowPx - labelLayout.size.height) / 2f)
            )
            val total = row.segments.sumOf { it.count }
            if (total <= 0) return@forEachIndexed
            val barTop = top + (rowPx - barPx) / 2f
            val totalWidth = (total.toFloat() / maxTotal * available).coerceAtLeast(barPx / 2f)
            val clip = Path().apply {
                addRoundRect(
                    RoundRect(
                        left = labelWidth,
                        top = barTop,
                        right = labelWidth + totalWidth,
                        bottom = barTop + barPx,
                        cornerRadius = CornerRadius(barPx / 2f)
                    )
                )
            }
            clipPath(clip) {
                var x = labelWidth
                row.segments.forEach { segment ->
                    if (segment.count <= 0) return@forEach
                    val width = segment.count.toFloat() / total * totalWidth
                    drawRect(
                        color = segment.color,
                        topLeft = Offset(x, barTop),
                        size = Size(width, barPx)
                    )
                    x += width
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun ChartLegend(
    items: List<Pair<String, Color>>,
    modifier: Modifier = Modifier
) {
    FlowRow(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        items.forEach { (label, color) ->
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .background(color, CircleShape)
                )
                Text(
                    text = label,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
internal fun GroupedBarChart(
    entries: List<Triple<String, Int, Int>>,
    firstColor: Color,
    secondColor: Color,
    modifier: Modifier = Modifier,
    showLabels: Boolean = true
) {
    if (entries.isEmpty()) return
    val textMeasurer = rememberTextMeasurer()
    val labelStyle = MaterialTheme.typography.labelSmall
        .copy(color = MaterialTheme.colorScheme.onSurfaceVariant)
    Canvas(modifier = modifier) {
        val labelArea = if (showLabels) 18.dp.toPx() else 0f
        val chartHeight = (size.height - labelArea).coerceAtLeast(1f)
        val maxValue = entries.maxOf { max(it.second, it.third) }.coerceAtLeast(1)
        val groupWidth = size.width / entries.size
        val barWidth = min(groupWidth * 0.28f, 14.dp.toPx())
        val gap = 2.dp.toPx()
        entries.forEachIndexed { index, (label, first, second) ->
            val centerX = groupWidth * index + groupWidth / 2f
            fun drawBar(value: Int, x: Float, color: Color) {
                val barHeight = value.toFloat() / maxValue * chartHeight
                if (barHeight <= 0f) return
                drawRoundRect(
                    color = color,
                    topLeft = Offset(x, chartHeight - barHeight),
                    size = Size(barWidth, barHeight),
                    cornerRadius = CornerRadius(barWidth / 3f)
                )
            }
            drawBar(first, centerX - barWidth - gap / 2f, firstColor)
            drawBar(second, centerX + gap / 2f, secondColor)
            if (showLabels && label.isNotEmpty()) {
                val labelLayout = textMeasurer.measure(label, labelStyle)
                drawText(
                    textLayoutResult = labelLayout,
                    topLeft = Offset(
                        centerX - labelLayout.size.width / 2f,
                        chartHeight + (labelArea - labelLayout.size.height) / 2f
                    )
                )
            }
        }
    }
}

@Composable
internal fun BigTotalsBarChart(
    bars: List<Triple<String, Int, Color>>,
    annotationFor: (Int) -> String,
    modifier: Modifier = Modifier
) {
    if (bars.isEmpty()) return
    val textMeasurer = rememberTextMeasurer()
    val labelStyle = MaterialTheme.typography.labelMedium
        .copy(color = MaterialTheme.colorScheme.onSurfaceVariant)
    val annotationStyle = MaterialTheme.typography.labelMedium
        .copy(color = MaterialTheme.colorScheme.onSurface)
    Canvas(modifier = modifier) {
        val annotationArea = 22.dp.toPx()
        val labelArea = 22.dp.toPx()
        val chartHeight = (size.height - annotationArea - labelArea).coerceAtLeast(1f)
        val maxValue = bars.maxOf { it.second }.coerceAtLeast(1)
        val groupWidth = size.width / bars.size
        val barWidth = min(groupWidth * 0.5f, 64.dp.toPx())
        bars.forEachIndexed { index, (label, value, color) ->
            val centerX = groupWidth * index + groupWidth / 2f
            val barHeight = value.toFloat() / maxValue * chartHeight
            if (barHeight > 0f) {
                drawRoundRect(
                    color = color,
                    topLeft = Offset(centerX - barWidth / 2f, annotationArea + chartHeight - barHeight),
                    size = Size(barWidth, barHeight),
                    cornerRadius = CornerRadius(8.dp.toPx())
                )
            }
            val annotationLayout = textMeasurer.measure(annotationFor(value), annotationStyle)
            drawText(
                textLayoutResult = annotationLayout,
                topLeft = Offset(
                    centerX - annotationLayout.size.width / 2f,
                    (annotationArea + chartHeight - barHeight - annotationLayout.size.height - 4.dp.toPx())
                        .coerceAtLeast(0f)
                )
            )
            val labelLayout = textMeasurer.measure(label, labelStyle)
            drawText(
                textLayoutResult = labelLayout,
                topLeft = Offset(
                    centerX - labelLayout.size.width / 2f,
                    annotationArea + chartHeight + (labelArea - labelLayout.size.height) / 2f
                )
            )
        }
    }
}
