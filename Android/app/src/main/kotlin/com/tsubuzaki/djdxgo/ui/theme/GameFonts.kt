package com.tsubuzaki.djdxgo.ui.theme

import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import com.tsubuzaki.djdxgo.R

enum class GameFontWidth(val width: Float, val counterWidth: Float) {
    COMPRESSED(40f, 360f),
    CONDENSED(75f, 420f),
    STANDARD(100f, 468f),
    EXPANDED(125f, 520f)
}

@OptIn(ExperimentalTextApi::class)
object GameFonts {
    private val weights = listOf(
        FontWeight.Normal, FontWeight.Medium, FontWeight.SemiBold,
        FontWeight.Bold, FontWeight.ExtraBold, FontWeight.Black
    )

    private val families: Map<GameFontWidth, FontFamily> = GameFontWidth.entries.associateWith { width ->
        FontFamily(
            weights.map { weight ->
                Font(
                    R.font.roboto_flex,
                    weight = weight,
                    variationSettings = FontVariation.Settings(
                        weight,
                        FontStyle.Normal,
                        FontVariation.width(width.width),
                        FontVariation.Setting("XTRA", width.counterWidth)
                    )
                )
            }
        )
    }

    fun family(width: GameFontWidth): FontFamily = families.getValue(width)
}

fun TextStyle.gameFont(width: GameFontWidth = GameFontWidth.EXPANDED): TextStyle =
    copy(fontFamily = GameFonts.family(width))
