package com.tsubuzaki.djdxgo.ui.common

import com.tsubuzaki.djdxgo.ui.theme.GameFontWidth
import com.tsubuzaki.djdxgo.ui.theme.gameFont
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.tsubuzaki.djdxgo.data.iidx.IIDXClearType
import com.tsubuzaki.djdxgo.ui.theme.IIDXColors

@Composable
fun rememberFullComboPhase(isActive: Boolean = true): Float {
    if (!isActive) return 0f
    val transition = rememberInfiniteTransition(label = "fullComboRainbow")
    val phase by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(3000, easing = LinearEasing), RepeatMode.Restart),
        label = "fullComboPhase"
    )
    return phase
}

@Composable
fun FullComboRainbowFill(modifier: Modifier = Modifier) {
    Box(modifier.background(IIDXColors.fullComboRainbowColor(rememberFullComboPhase())))
}

@Composable
fun IIDXClearTypeText(
    clearType: String,
    style: TextStyle,
    modifier: Modifier = Modifier,
    label: String = clearType,
    outlineWidth: Dp = 0.3.dp,
    fontWidth: GameFontWidth = GameFontWidth.EXPANDED,
    fontWeight: FontWeight = FontWeight.ExtraBold
) {
    val phase = rememberFullComboPhase(IIDXClearType.fromValue(clearType) == IIDXClearType.FULL_COMBO_CLEAR)
    OutlinedText(
        text = label,
        style = style.gameFont(fontWidth).merge(TextStyle(letterSpacing = (-0.3).sp)),
        fill = IIDXColors.clearTypeBrush(clearType, phase),
        outline = Color.Black,
        outlineWidth = outlineWidth,
        modifier = modifier,
        fontWeight = fontWeight
    )
}

@Composable
fun IIDXDJLevelText(
    djLevel: String,
    style: TextStyle,
    modifier: Modifier = Modifier,
    outlineWidth: Dp = 0.3.dp,
    fontWidth: GameFontWidth = GameFontWidth.EXPANDED,
    fontWeight: FontWeight = FontWeight.Black
) {
    OutlinedText(
        text = djLevel,
        style = style.gameFont(fontWidth),
        fill = IIDXColors.djLevelBrush(djLevel),
        outline = Color.Black,
        outlineWidth = outlineWidth,
        modifier = modifier,
        fontWeight = fontWeight
    )
}
