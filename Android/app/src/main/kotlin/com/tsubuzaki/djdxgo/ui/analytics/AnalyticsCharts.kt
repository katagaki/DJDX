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
import androidx.compose.foundation.layout.fillMaxSize
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
import androidx.compose.runtime.remember
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.Dp
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
    modifier: Modifier = Modifier,
    fillsHeight: Boolean = false
) {
    if (entries.isEmpty()) return
    val textMeasurer = rememberTextMeasurer()
    val labelStyle = MaterialTheme.typography.labelSmall
        .copy(color = MaterialTheme.colorScheme.onSurfaceVariant)
    val countStyle = MaterialTheme.typography.labelSmall
        .copy(color = MaterialTheme.colorScheme.onSurface)
    val rowHeight = 24.dp
    Canvas(
        modifier = if (fillsHeight) {
            modifier.fillMaxSize()
        } else {
            modifier
                .fillMaxWidth()
                .height(rowHeight * entries.size)
        }
    ) {
        val rowPx = min(rowHeight.toPx(), size.height / entries.size)
        val barPx = min(14.dp.toPx(), rowPx * 0.7f)
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

internal data class ChartSegment(val label: String, val count: Int, val color: Color)

@Composable
internal fun SegmentedBar(
    segments: List<ChartSegment>,
    modifier: Modifier = Modifier,
    height: Dp = 10.dp,
    cornerRadius: Dp = 3.dp
) {
    val total = segments.sumOf { it.count }.coerceAtLeast(1)
    Canvas(
        modifier = modifier
            .fillMaxWidth()
            .height(height)
    ) {
        val clip = Path().apply {
            addRoundRect(RoundRect(0f, 0f, size.width, size.height, CornerRadius(cornerRadius.toPx())))
        }
        clipPath(clip) {
            var x = 0f
            segments.filter { it.count > 0 }.forEach { segment ->
                val width = segment.count.toFloat() / total * size.width
                drawRect(segment.color, topLeft = Offset(x, 0f), size = Size(width, size.height))
                x += width
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun BreakdownBar(items: List<ChartSegment>, modifier: Modifier = Modifier) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SegmentedBar(segments = items, height = 18.dp, cornerRadius = 9.dp)
        FlowRow(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            items.forEach { item ->
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(5.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(10.dp)
                            .background(item.color, RoundedCornerShape(2.dp))
                    )
                    Text(
                        text = item.label,
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1
                    )
                    Text(
                        text = item.count.toString(),
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }
        }
    }
}

@Composable
internal fun PieChart(segments: List<ChartSegment>, modifier: Modifier = Modifier) {
    val visible = segments.filter { it.count > 0 }
    val total = visible.sumOf { it.count }
    Canvas(modifier = modifier) {
        if (total <= 0) return@Canvas
        val diameter = min(size.width, size.height)
        val topLeft = Offset((size.width - diameter) / 2f, (size.height - diameter) / 2f)
        var startAngle = -90f
        visible.forEach { segment ->
            val sweep = segment.count.toFloat() / total * 360f
            drawArc(
                color = segment.color,
                startAngle = startAngle,
                sweepAngle = sweep,
                useCenter = true,
                topLeft = topLeft,
                size = Size(diameter, diameter)
            )
            startAngle += sweep
        }
    }
}

internal data class AreaSeriesPoint(val x: Long, val values: List<ChartSegment>)

@Composable
internal fun StackedAreaChart(
    points: List<AreaSeriesPoint>,
    modifier: Modifier = Modifier,
    showAxes: Boolean = true
) {
    val textMeasurer = rememberTextMeasurer()
    val labelStyle = MaterialTheme.typography.labelSmall
        .copy(color = MaterialTheme.colorScheme.onSurfaceVariant)
    val gridColor = MaterialTheme.colorScheme.outlineVariant
    val dateFormatter = remember { java.time.format.DateTimeFormatter.ofPattern("M/d") }
    Canvas(modifier = modifier) {
        if (points.isEmpty()) return@Canvas
        val labelArea = if (showAxes) 18.dp.toPx() else 0f
        val chartHeight = (size.height - labelArea).coerceAtLeast(1f)
        val maxTotal = points.maxOf { point -> point.values.sumOf { it.count } }.coerceAtLeast(1)
        val minX = points.first().x
        val maxX = points.last().x
        val span = (maxX - minX).coerceAtLeast(1L).toFloat()
        fun xFor(point: AreaSeriesPoint): Float =
            if (points.size == 1) size.width / 2f else (point.x - minX) / span * size.width
        fun yFor(value: Int): Float = chartHeight - value.toFloat() / maxTotal * chartHeight
        if (showAxes) {
            listOf(0f, 0.5f, 1f).forEach { fraction ->
                val y = chartHeight * fraction
                drawLine(gridColor, Offset(0f, y), Offset(size.width, y), strokeWidth = 1f)
            }
        }
        val seriesCount = points.first().values.size
        val baselines = IntArray(points.size)
        for (seriesIndex in (0 until seriesCount).reversed()) {
            val tops = points.mapIndexed { index, point ->
                baselines[index] + (point.values.getOrNull(seriesIndex)?.count ?: 0)
            }
            val color = points.first().values[seriesIndex].color
            val path = Path()
            if (points.size == 1) {
                path.addRect(
                    androidx.compose.ui.geometry.Rect(0f, yFor(tops[0]), size.width, yFor(baselines[0]))
                )
            } else {
                points.forEachIndexed { index, point ->
                    val x = xFor(point)
                    val y = yFor(tops[index])
                    if (index == 0) path.moveTo(x, y) else path.lineTo(x, y)
                }
                for (index in points.indices.reversed()) {
                    path.lineTo(xFor(points[index]), yFor(baselines[index]))
                }
                path.close()
            }
            drawPath(path, color)
            tops.forEachIndexed { index, value -> baselines[index] = value }
        }
        if (showAxes) {
            val labelIndices = if (points.size <= 2) {
                points.indices.toList()
            } else {
                listOf(0, points.size / 2, points.size - 1).distinct()
            }
            labelIndices.forEach { index ->
                val point = points[index]
                val text = java.time.Instant.ofEpochSecond(point.x)
                    .atZone(java.time.ZoneId.systemDefault())
                    .toLocalDate()
                    .format(dateFormatter)
                val layout = textMeasurer.measure(text, labelStyle)
                val x = (xFor(point) - layout.size.width / 2f)
                    .coerceIn(0f, (size.width - layout.size.width).coerceAtLeast(0f))
                drawText(layout, topLeft = Offset(x, chartHeight + (labelArea - layout.size.height) / 2f))
            }
        }
    }
}

internal data class BarColumn(val label: String, val segments: List<ChartSegment>)

@Composable
internal fun VerticalStackedBarChart(
    columns: List<BarColumn>,
    modifier: Modifier = Modifier
) {
    val textMeasurer = rememberTextMeasurer()
    val labelStyle = MaterialTheme.typography.labelSmall
        .copy(color = MaterialTheme.colorScheme.onSurfaceVariant)
    val gridColor = MaterialTheme.colorScheme.outlineVariant
    Canvas(modifier = modifier) {
        if (columns.isEmpty()) return@Canvas
        val labelArea = 18.dp.toPx()
        val chartHeight = (size.height - labelArea).coerceAtLeast(1f)
        val maxTotal = columns.maxOf { column -> column.segments.sumOf { it.count } }.coerceAtLeast(1)
        val columnWidth = size.width / columns.size
        val barWidth = min(columnWidth * 0.7f, 28.dp.toPx())
        listOf(0f, 0.5f, 1f).forEach { fraction ->
            val y = chartHeight * fraction
            drawLine(gridColor, Offset(0f, y), Offset(size.width, y), strokeWidth = 1f)
        }
        columns.forEachIndexed { index, column ->
            val centerX = columnWidth * index + columnWidth / 2f
            var top = chartHeight
            column.segments.reversed().forEach { segment ->
                if (segment.count <= 0) return@forEach
                val height = segment.count.toFloat() / maxTotal * chartHeight
                drawRect(
                    color = segment.color,
                    topLeft = Offset(centerX - barWidth / 2f, top - height),
                    size = Size(barWidth, height)
                )
                top -= height
            }
            val layout = textMeasurer.measure(column.label, labelStyle)
            drawText(
                layout,
                topLeft = Offset(
                    centerX - layout.size.width / 2f,
                    chartHeight + (labelArea - layout.size.height) / 2f
                )
            )
        }
    }
}
