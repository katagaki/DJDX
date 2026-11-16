package com.tsubuzaki.djdxgo.ui.iidx

import androidx.annotation.StringRes
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Shuffle
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.iidx.IIDXChartTrait
import kotlin.math.min

@Composable
fun IIDXChartTraitsRow(traits: List<IIDXChartTrait>?, modifier: Modifier = Modifier) {
    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = stringResource(R.string.scores_viewer_characteristics),
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.Bold
        )
        when {
            traits == null -> Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
                Text(
                    text = stringResource(R.string.scores_viewer_chart_type_analyzing),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            traits.isEmpty() -> Text(
                text = stringResource(R.string.scores_viewer_chart_type_none),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            else -> FlowRow(
                horizontalArrangement = Arrangement.spacedBy(14.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                traits.forEach { trait ->
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        IIDXChartTraitIcon(trait)
                        Text(
                            text = stringResource(trait.nameRes),
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun IIDXChartTraitIcon(trait: IIDXChartTrait, iconSize: Dp = 26.dp) {
    val shape = RoundedCornerShape(iconSize * 0.24f)
    Box(
        modifier = Modifier
            .size(iconSize)
            .background(Brush.verticalGradient(listOf(lerp(trait.color, Color.White, 0.15f), trait.color)), shape)
            .border(0.5.dp, Color.Black.copy(alpha = 0.18f), shape),
        contentAlignment = Alignment.Center
    ) {
        val vector = trait.vector
        if (vector != null) {
            Icon(vector, contentDescription = null, tint = Color.White, modifier = Modifier.size(iconSize * 0.62f))
        } else {
            val (width, height) = trait.glyphSize
            Canvas(modifier = Modifier.size(iconSize * width, iconSize * height)) {
                translate(top = 0.5.dp.toPx()) { drawGlyph(trait, iconSize.toPx(), Color.Black.copy(alpha = 0.2f)) }
                drawGlyph(trait, iconSize.toPx(), Color.White)
            }
        }
    }
}

private val IIDXChartTrait.vector: ImageVector?
    get() = when (this) {
        IIDXChartTrait.BURST -> Icons.Filled.Bolt
        IIDXChartTrait.STAMINA -> Icons.Filled.LocalFireDepartment
        IIDXChartTrait.CHAOTIC -> Icons.Filled.Shuffle
        else -> null
    }

private val IIDXChartTrait.glyphSize: Pair<Float, Float>
    get() = when (this) {
        IIDXChartTrait.BACKLOADED, IIDXChartTrait.BUILD_UP,
        IIDXChartTrait.GRADUAL_SOFLAN, IIDXChartTrait.SUDDEN_SOFLAN -> 0.62f to 0.5f
        IIDXChartTrait.CHARGE_COMBO -> 0.62f to 0.54f
        IIDXChartTrait.CHARGE_CHORDS -> 0.66f to 0.54f
        IIDXChartTrait.SCRATCH_COMBO -> 0.6f to 0.46f
        IIDXChartTrait.LEGACY_NOTES -> 0.66f to 0.46f
        else -> 0.7f to 0.56f
    }

private val IIDXChartTrait.noteGridRows: List<List<Int>>
    get() = when (this) {
        IIDXChartTrait.STAIRS -> listOf(listOf(0), listOf(1), listOf(2), listOf(3))
        IIDXChartTrait.CONSECUTIVE_CHORDS -> listOf(listOf(0, 2), listOf(1, 3), listOf(0, 2))
        IIDXChartTrait.ADJACENT_PAIRS -> listOf(listOf(2, 3), listOf(0, 1), listOf(1, 2))
        IIDXChartTrait.JACKS -> listOf(listOf(1), listOf(1), listOf(2), listOf(2))
        else -> emptyList()
    }

@get:StringRes
private val IIDXChartTrait.nameRes: Int
    get() = when (this) {
        IIDXChartTrait.BACKLOADED -> R.string.scores_viewer_chart_type_backloaded
        IIDXChartTrait.BUILD_UP -> R.string.scores_viewer_chart_type_build_up
        IIDXChartTrait.BURST -> R.string.scores_viewer_chart_type_burst
        IIDXChartTrait.STAMINA -> R.string.scores_viewer_chart_type_stamina
        IIDXChartTrait.CHAOTIC -> R.string.scores_viewer_chart_type_chaotic
        IIDXChartTrait.STAIRS -> R.string.scores_viewer_chart_type_stairs
        IIDXChartTrait.CONSECUTIVE_CHORDS -> R.string.scores_viewer_chart_type_consecutive_chords
        IIDXChartTrait.ADJACENT_PAIRS -> R.string.scores_viewer_chart_type_adjacent_pairs
        IIDXChartTrait.JACKS -> R.string.scores_viewer_chart_type_jacks
        IIDXChartTrait.SCRATCH_COMBO -> R.string.scores_viewer_chart_type_scratch_combo
        IIDXChartTrait.LEGACY_NOTES -> R.string.scores_viewer_chart_type_legacy_notes
        IIDXChartTrait.CHARGE_COMBO -> R.string.scores_viewer_chart_type_charge_combo
        IIDXChartTrait.CHARGE_CHORDS -> R.string.scores_viewer_chart_type_charge_chords
        IIDXChartTrait.GRADUAL_SOFLAN -> R.string.scores_viewer_chart_type_gradual_soflan
        IIDXChartTrait.SUDDEN_SOFLAN -> R.string.scores_viewer_chart_type_sudden_soflan
    }

private val IIDXChartTrait.color: Color
    get() = when (this) {
        IIDXChartTrait.BACKLOADED -> Color(255, 149, 0)
        IIDXChartTrait.BUILD_UP -> Color(124, 168, 20)
        IIDXChartTrait.BURST -> Color(230, 175, 0)
        IIDXChartTrait.STAMINA -> Color(255, 45, 85)
        IIDXChartTrait.CHAOTIC -> Color(52, 178, 89)
        IIDXChartTrait.STAIRS -> Color(0, 168, 196)
        IIDXChartTrait.CONSECUTIVE_CHORDS -> Color(162, 126, 84)
        IIDXChartTrait.ADJACENT_PAIRS -> Color(200, 64, 170)
        IIDXChartTrait.JACKS -> Color(96, 112, 140)
        IIDXChartTrait.SCRATCH_COMBO -> Color(221, 0, 0)
        IIDXChartTrait.LEGACY_NOTES -> Color(150, 40, 70)
        IIDXChartTrait.CHARGE_COMBO -> Color(137, 87, 221)
        IIDXChartTrait.CHARGE_CHORDS -> Color(20, 140, 120)
        IIDXChartTrait.GRADUAL_SOFLAN -> Color(0, 134, 229)
        IIDXChartTrait.SUDDEN_SOFLAN -> Color(88, 86, 214)
    }

// MARK: - Glyphs

private fun DrawScope.drawGlyph(trait: IIDXChartTrait, iconSize: Float, color: Color) {
    when (trait) {
        IIDXChartTrait.BACKLOADED, IIDXChartTrait.BUILD_UP,
        IIDXChartTrait.GRADUAL_SOFLAN, IIDXChartTrait.SUDDEN_SOFLAN -> {
            drawPath(graphPath(trait, closed = true), color.copy(alpha = color.alpha * 0.45f))
            drawPath(
                graphPath(trait, closed = false),
                color,
                style = Stroke(width = iconSize * 0.07f, cap = StrokeCap.Round, join = StrokeJoin.Round)
            )
        }
        IIDXChartTrait.CHARGE_COMBO -> drawChargeCombo(color)
        IIDXChartTrait.CHARGE_CHORDS -> drawChargeChords(color)
        IIDXChartTrait.SCRATCH_COMBO -> drawTurntable(color, 0.52f) { diameter, lineWidth ->
            val left = diameter + size.width * 0.1f
            val barHeight = diameter * 0.2f
            val spacing = diameter * 0.14f
            val top = (size.height - (barHeight * 3 + spacing * 2)) / 2f
            repeat(3) { index ->
                drawRoundRect(
                    color,
                    topLeft = Offset(left, top + (barHeight + spacing) * index),
                    size = Size(size.width - left, barHeight),
                    cornerRadius = CornerRadius(lineWidth * 0.4f)
                )
            }
        }
        IIDXChartTrait.LEGACY_NOTES -> drawTurntable(color, 0.5f) { diameter, _ ->
            drawThree(color, Rect(diameter + size.width * 0.1f, 0f, size.width, size.height))
        }
        else -> drawNoteGrid(trait.noteGridRows, color)
    }
}

private fun DrawScope.point(horizontal: Float, vertical: Float) =
    Offset(horizontal * size.width, vertical * size.height)

private fun DrawScope.graphPath(trait: IIDXChartTrait, closed: Boolean): Path = Path().apply {
    fun move(x: Float, y: Float) = point(x, y).let { moveTo(it.x, it.y) }
    fun line(x: Float, y: Float) = point(x, y).let { lineTo(it.x, it.y) }
    fun quad(x: Float, y: Float, cx: Float, cy: Float) {
        val control = point(cx, cy)
        val end = point(x, y)
        quadraticTo(control.x, control.y, end.x, end.y)
    }
    fun cubic(x: Float, y: Float, c1x: Float, c1y: Float, c2x: Float, c2y: Float) {
        val control1 = point(c1x, c1y)
        val control2 = point(c2x, c2y)
        val end = point(x, y)
        cubicTo(control1.x, control1.y, control2.x, control2.y, end.x, end.y)
    }
    when (trait) {
        IIDXChartTrait.BACKLOADED -> {
            move(0f, 0.78f)
            quad(0.14f, 0.78f, 0.07f, 0.66f)
            quad(0.28f, 0.78f, 0.21f, 0.90f)
            quad(0.42f, 0.78f, 0.35f, 0.66f)
            quad(0.54f, 0.80f, 0.48f, 0.88f)
            cubic(0.78f, 0.06f, 0.64f, 0.72f, 0.70f, 0.06f)
            cubic(1f, 0.82f, 0.88f, 0.06f, 0.90f, 0.80f)
        }
        IIDXChartTrait.BUILD_UP -> {
            move(0f, 0.86f)
            line(0.2f, 0.66f)
            line(0.32f, 0.74f)
            line(0.52f, 0.46f)
            line(0.64f, 0.54f)
            line(0.84f, 0.24f)
            line(1f, 0.08f)
        }
        IIDXChartTrait.GRADUAL_SOFLAN -> {
            move(0f, 0.86f)
            cubic(1f, 0.08f, 0.55f, 0.86f, 0.62f, 0.08f)
        }
        else -> {
            move(0f, 0.82f)
            line(0.46f, 0.82f)
            line(0.46f, 0.12f)
            line(1f, 0.12f)
        }
    }
    if (closed) {
        line(1f, 1f)
        line(0f, 1f)
        close()
    }
}

private fun DrawScope.drawChargeCombo(color: Color) {
    val chargeWidth = size.width * 0.24f
    drawRoundRect(
        color,
        topLeft = Offset(center.x - chargeWidth / 2f, 0f),
        size = Size(chargeWidth, size.height),
        cornerRadius = CornerRadius(chargeWidth * 0.35f)
    )
    val noteWidth = size.width * 0.3f
    val noteHeight = size.height * 0.16f
    listOf(true, false, true).forEachIndexed { index, isLeft ->
        drawRoundRect(
            color,
            topLeft = Offset(if (isLeft) 0f else size.width - noteWidth, size.height * (0.06f + index * 0.36f)),
            size = Size(noteWidth, noteHeight),
            cornerRadius = CornerRadius(noteHeight * 0.4f)
        )
    }
}

private fun DrawScope.drawChargeChords(color: Color) {
    val columnWidth = size.width / 3f
    val noteWidth = columnWidth * 0.82f
    val noteHeight = size.height * 0.2f
    repeat(3) { column ->
        val height = if (column == 1) size.height else noteHeight
        drawRoundRect(
            color,
            topLeft = Offset(columnWidth * column + (columnWidth - noteWidth) / 2f, size.height - height),
            size = Size(noteWidth, height),
            cornerRadius = CornerRadius(noteHeight * 0.4f)
        )
    }
}

private fun DrawScope.drawNoteGrid(rows: List<List<Int>>, color: Color) {
    if (rows.isEmpty()) return
    val columnWidth = size.width / 4f
    val rowHeight = size.height / rows.size
    val noteWidth = columnWidth * 0.9f
    val noteHeight = min(rowHeight * 0.7f, noteWidth * 0.5f)
    rows.forEachIndexed { rowIndex, columns ->
        val top = rowHeight * rowIndex + (rowHeight - noteHeight) / 2f
        columns.forEach { column ->
            drawRoundRect(
                color,
                topLeft = Offset(columnWidth * column + (columnWidth - noteWidth) / 2f, top),
                size = Size(noteWidth, noteHeight),
                cornerRadius = CornerRadius(noteHeight * 0.35f)
            )
        }
    }
}

private fun DrawScope.drawTurntable(
    color: Color,
    widthRatio: Float,
    trailing: DrawScope.(diameter: Float, lineWidth: Float) -> Unit
) {
    val diameter = min(size.height, size.width * widthRatio)
    val lineWidth = diameter * 0.16f
    val discCenter = Offset(diameter / 2f, size.height / 2f)
    drawCircle(color, radius = (diameter - lineWidth) / 2f, center = discCenter, style = Stroke(lineWidth))
    drawCircle(color, radius = diameter * 0.13f, center = discCenter)
    trailing(diameter, lineWidth)
}

private fun DrawScope.drawThree(color: Color, bounds: Rect) {
    val height = min(bounds.height, bounds.width * 1.4f)
    val width = height * 0.62f
    val left = bounds.left + (bounds.width - width) / 2f
    val top = bounds.top + (bounds.height - height) / 2f
    val stroke = height * 0.2f
    val path = Path().apply {
        moveTo(left, top + stroke / 2f)
        lineTo(left + width - stroke / 2f, top + stroke / 2f)
        lineTo(left + width * 0.42f, top + height * 0.46f)
        quadraticTo(left + width, top + height * 0.46f, left + width - stroke / 2f, top + height * 0.72f)
        quadraticTo(left + width * 0.7f, top + height - stroke / 2f, left, top + height * 0.84f)
    }
    drawPath(path, color, style = Stroke(width = stroke, cap = StrokeCap.Round, join = StrokeJoin.Round))
}
