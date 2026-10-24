package com.tsubuzaki.djdxgo.ui.common

import android.graphics.Bitmap
import android.graphics.DashPathEffect
import android.graphics.Paint
import android.graphics.Typeface
import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.tsubuzaki.djdxgo.data.RadarAxis
import com.tsubuzaki.djdxgo.data.RadarData
import com.tsubuzaki.djdxgo.ui.theme.RadarColors
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

private const val RADAR_MAX_VALUE = 130.0
private const val RADAR_BENCHMARK_VALUE = 100.0

private fun angle(axis: RadarAxis): Double =
    -PI / 2 - RadarAxis.chartOrder.indexOf(axis) * PI / 3

@Composable
fun RadarChart(
    data: RadarData,
    color: Color,
    modifier: Modifier = Modifier,
    labelSize: Dp = 12.dp,
    lineWidth: Dp = 2.dp
) {
    val density = LocalDensity.current
    val labelSizePx = with(density) { labelSize.toPx() }
    val lineWidthPx = with(density) { lineWidth.toPx() }
    val insetPx = with(density) { 30.dp.toPx() }
    Canvas(modifier = modifier) {
        drawIntoCanvas { canvas ->
            drawRadar(
                canvas = canvas.nativeCanvas,
                width = size.width,
                height = size.height,
                data = data,
                color = color,
                labelSizePx = labelSizePx,
                lineWidthPx = lineWidthPx,
                insetPx = insetPx
            )
        }
    }
}

fun drawRadar(
    canvas: android.graphics.Canvas,
    width: Float,
    height: Float,
    data: RadarData,
    color: Color,
    labelSizePx: Float,
    lineWidthPx: Float,
    insetPx: Float
) {
    val chartSize = min(width - insetPx, height - insetPx).coerceAtLeast(1f)
    val centerX = width / 2f
    val centerY = height / 2f
    val radius = chartSize / 2f
    val benchmarkRadius = radius * (RADAR_BENCHMARK_VALUE / RADAR_MAX_VALUE).toFloat()

    val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }

    fillPaint.color = Color.Gray.copy(alpha = 0.5f).toArgb()
    canvas.drawCircle(centerX, centerY, benchmarkRadius, fillPaint)
    strokePaint.color = Color.Gray.copy(alpha = 0.8f).toArgb()
    strokePaint.strokeWidth = 2f
    canvas.drawCircle(centerX, centerY, benchmarkRadius, strokePaint)

    strokePaint.color = Color.Gray.copy(alpha = 0.4f).toArgb()
    strokePaint.strokeWidth = 1.5f
    strokePaint.pathEffect = DashPathEffect(floatArrayOf(8f, 8f), 0f)
    RadarAxis.chartOrder.forEach { axis ->
        val theta = angle(axis)
        canvas.drawLine(
            centerX, centerY,
            centerX + radius * cos(theta).toFloat(),
            centerY + radius * sin(theta).toFloat(),
            strokePaint
        )
    }
    strokePaint.pathEffect = null

    val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textSize = labelSizePx
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        letterSpacing = 0.05f
    }
    val metrics = textPaint.fontMetrics
    RadarAxis.chartOrder.forEach { axis ->
        val theta = angle(axis)
        val tipX = centerX + radius * cos(theta).toFloat()
        val tipY = centerY + radius * sin(theta).toFloat()
        val axisColor = RadarColors.axisColor(axis)
        textPaint.color = lerp(axisColor, Color.White, 0.6f).toArgb()
        textPaint.setShadowLayer(labelSizePx / 3f, 0f, 0f, axisColor.toArgb())
        val textWidth = textPaint.measureText(axis.label)
        val horizontalCos = cos(theta)
        val x = when {
            horizontalCos > 0.1 -> tipX
            horizontalCos < -0.1 -> tipX - textWidth
            else -> tipX - textWidth / 2f
        }
        val baseline = if (sin(theta) < 0) tipY - metrics.descent else tipY - metrics.ascent
        canvas.drawText(axis.label, x, baseline, textPaint)
    }

    val path = android.graphics.Path()
    RadarAxis.chartOrder.forEachIndexed { index, axis ->
        val theta = angle(axis)
        val pointRadius = radius * (data.value(axis) / RADAR_MAX_VALUE).coerceAtLeast(0.0).toFloat()
        val x = centerX + pointRadius * cos(theta).toFloat()
        val y = centerY + pointRadius * sin(theta).toFloat()
        if (index == 0) path.moveTo(x, y) else path.lineTo(x, y)
    }
    path.close()
    fillPaint.color = color.copy(alpha = 0.5f).toArgb()
    canvas.drawPath(path, fillPaint)
    strokePaint.color = color.toArgb()
    strokePaint.strokeWidth = lineWidthPx
    strokePaint.strokeJoin = Paint.Join.ROUND
    canvas.drawPath(path, strokePaint)
}

fun renderRadarBitmap(
    data: RadarData,
    color: Color,
    density: Float
): Bitmap {
    val width = (640 * density).toInt()
    val height = (600 * density).toInt()
    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    val canvas = android.graphics.Canvas(bitmap)
    canvas.drawColor(android.graphics.Color.BLACK)
    val horizontalPadding = 80f * density
    val verticalPadding = 110f * density
    canvas.translate(horizontalPadding, verticalPadding)
    drawRadar(
        canvas = canvas,
        width = width - horizontalPadding * 2,
        height = height - verticalPadding * 2,
        data = data,
        color = color,
        labelSizePx = 20f * density,
        lineWidthPx = 2.5f * density,
        insetPx = 30f * density
    )
    return bitmap
}
