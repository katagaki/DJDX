package com.tsubuzaki.djdxgo.ui.common

import androidx.compose.foundation.layout.Box
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp

@Composable
fun OutlinedText(
    text: String,
    style: TextStyle,
    fill: Brush,
    outline: Color,
    outlineWidth: Dp,
    modifier: Modifier = Modifier,
    fontWeight: FontWeight? = null,
    textAlign: TextAlign? = null,
    squashed: Boolean = false
) {
    val strokePx = with(LocalDensity.current) { (outlineWidth * 4f).toPx() }
    val layers: @Composable () -> Unit = {
        Box {
            if (strokePx > 0f) {
                Text(
                    text = text,
                    style = style.merge(
                        TextStyle(
                            brush = SolidColor(outline),
                            drawStyle = Stroke(width = strokePx, join = StrokeJoin.Round)
                        )
                    ),
                    fontWeight = fontWeight,
                    textAlign = textAlign,
                    maxLines = 1,
                    softWrap = false,
                    overflow = TextOverflow.Visible
                )
            }
            Text(
                text = text,
                style = style.merge(TextStyle(brush = fill)),
                fontWeight = fontWeight,
                textAlign = textAlign,
                maxLines = 1,
                softWrap = false,
                overflow = TextOverflow.Visible
            )
        }
    }
    if (squashed) {
        SquashedHorizontally(modifier, layers)
    } else {
        Box(modifier) { layers() }
    }
}

@Composable
fun OutlinedText(
    text: String,
    style: TextStyle,
    fill: Color,
    outline: Color,
    outlineWidth: Dp,
    modifier: Modifier = Modifier,
    fontWeight: FontWeight? = null,
    textAlign: TextAlign? = null,
    squashed: Boolean = false
) = OutlinedText(text, style, SolidColor(fill), outline, outlineWidth, modifier, fontWeight, textAlign, squashed)

@Composable
fun SquashedHorizontally(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Layout(content = content, modifier = modifier) { measurables, constraints ->
        val placeable = measurables.first().measure(
            constraints.copy(minWidth = 0, maxWidth = Constraints.Infinity)
        )
        val width = if (constraints.hasBoundedWidth) constraints.maxWidth else placeable.width
        val scale = if (placeable.width > width && placeable.width > 0) {
            width.toFloat() / placeable.width
        } else {
            1f
        }
        layout(width, placeable.height) {
            placeable.placeWithLayer(0, 0) {
                scaleX = scale
                transformOrigin = TransformOrigin(0f, 0.5f)
            }
        }
    }
}
