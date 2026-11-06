package com.tsubuzaki.djdxgo.ui.common

import android.graphics.Bitmap
import android.graphics.BlurMaskFilter
import android.graphics.Paint
import android.graphics.Typeface
import android.provider.Settings
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.asComposePath
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Fill
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.ui.theme.HitlineJudgmentStyle
import kotlin.math.ceil

private const val HITLINE_ASCENT = 0.85f
private const val HITLINE_MITER_LIMIT = 4f
private val hitlineRingColors = listOf(Color(0xFF6E6E6E), Color(0xFF242424))

private class HitlineShadow(val mask: Bitmap, val inset: Float)

private class HitlineOutline(
    val path: Path,
    val width: Float,
    val edgeShadow: HitlineShadow,
    val glowShadow: HitlineShadow
)

private fun hitlineShadow(
    outline: android.graphics.Path,
    width: Float,
    height: Float,
    strokeWidth: Float,
    radius: Float
): HitlineShadow {
    val inset = ceil(strokeWidth + radius * 3f)
    val mask = Bitmap.createBitmap(
        ceil(width + inset * 2f).toInt(),
        ceil(height + inset * 2f).toInt(),
        Bitmap.Config.ALPHA_8
    )
    val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL_AND_STROKE
        this.strokeWidth = strokeWidth
        strokeJoin = Paint.Join.MITER
        strokeMiter = HITLINE_MITER_LIMIT
        maskFilter = BlurMaskFilter(radius, BlurMaskFilter.Blur.NORMAL)
    }
    android.graphics.Canvas(mask).apply {
        translate(inset, inset)
        drawPath(outline, paint)
    }
    return HitlineShadow(mask, inset)
}

private fun hitlineOutline(
    typeface: Typeface,
    text: String,
    sizePx: Float,
    scalePx: Float
): HitlineOutline {
    val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        this.typeface = typeface
        textSize = sizePx
        isLinearText = true
        isSubpixelText = true
    }
    val path = android.graphics.Path()
    paint.getTextPath(text, 0, text.length, 0f, sizePx * HITLINE_ASCENT, path)
    val width = paint.measureText(text)
    return HitlineOutline(
        path = path.asComposePath(),
        width = width,
        edgeShadow = hitlineShadow(path, width, sizePx, 6f * scalePx, scalePx),
        glowShadow = hitlineShadow(path, width, sizePx, 6f * scalePx, 10f * scalePx)
    )
}

private fun DrawScope.drawShadow(shadow: HitlineShadow, color: Color, paint: Paint) {
    paint.color = color.toArgb()
    drawIntoCanvas {
        it.nativeCanvas.drawBitmap(shadow.mask, -shadow.inset, -shadow.inset, paint)
    }
}

private fun hitlineStroke(width: Float) = Stroke(
    width = width,
    miter = HITLINE_MITER_LIMIT,
    cap = StrokeCap.Butt,
    join = StrokeJoin.Miter
)

@Composable
fun HitlineJudgmentText(
    text: String,
    size: Dp,
    style: () -> HitlineJudgmentStyle,
    modifier: Modifier = Modifier,
    outlineScale: Float = 1f
) {
    val context = LocalContext.current
    val density = LocalDensity.current
    val sizePx = with(density) { size.toPx() }
    val scalePx = density.density * outlineScale
    val typeface = remember(context) { context.resources.getFont(R.font.hitline_black) }
    val outline = remember(typeface, text, sizePx, scalePx) {
        hitlineOutline(typeface, text, sizePx, scalePx)
    }
    val shadowPaint = remember { Paint(Paint.ANTI_ALIAS_FLAG) }
    val ring = remember(sizePx) {
        Brush.verticalGradient(hitlineRingColors, startY = 0f, endY = sizePx)
    }
    val outerStroke = remember(scalePx) { hitlineStroke(6f * scalePx) }
    val ringStroke = remember(scalePx) { hitlineStroke(4f * scalePx) }
    val edgeStroke = remember(scalePx) { hitlineStroke(2f * scalePx) }

    Canvas(modifier.size(with(density) { outline.width.toDp() }, size)) {
        val current = style()
        drawShadow(outline.glowShadow, current.glow, shadowPaint)
        drawShadow(outline.edgeShadow, current.edge, shadowPaint)
        drawPath(outline.path, Color.Black, style = Fill)
        drawPath(outline.path, Color.Black, style = outerStroke)
        drawPath(outline.path, ring, style = Fill)
        drawPath(outline.path, ring, style = ringStroke)
        drawPath(outline.path, current.fillBrush(sizePx), style = Fill)
        drawPath(outline.path, current.edge, style = edgeStroke)
    }
}

@Composable
fun HitlineRainbowText(
    text: String,
    size: Dp,
    modifier: Modifier = Modifier,
    outlineScale: Float = 1f,
    periodMillis: Int = 500
) {
    val resolver = LocalContext.current.contentResolver
    val reduceMotion = remember(resolver) {
        Settings.Global.getFloat(resolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
    }
    if (reduceMotion) {
        HitlineJudgmentText(
            text = text,
            size = size,
            style = { HitlineJudgmentStyle.rainbow(0.5f) },
            modifier = modifier,
            outlineScale = outlineScale
        )
    } else {
        val hue by rememberInfiniteTransition(label = "hitlineRainbow").animateFloat(
            initialValue = 0f,
            targetValue = 1f,
            animationSpec = infiniteRepeatable(
                tween(periodMillis, easing = LinearEasing),
                RepeatMode.Restart
            ),
            label = "hitlineRainbowHue"
        )
        HitlineJudgmentText(
            text = text,
            size = size,
            style = { HitlineJudgmentStyle.rainbow(hue) },
            modifier = modifier,
            outlineScale = outlineScale
        )
    }
}
