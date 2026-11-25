package com.tsubuzaki.djdxgo.ui.share

import androidx.annotation.DrawableRes
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp

data class ShareCardMetric(val text: String, val brush: Brush)

data class ShareCardEntry(
    val title: String,
    val subtitle: String? = null,
    val lamp: Brush,
    val levelText: String,
    val difficultyText: String,
    val difficultyColor: Color,
    val metrics: List<ShareCardMetric>
)

data class ShareCardRating(val label: String, val value: String)

data class ShareCardProfile(
    val playerName: String? = null,
    val ratings: List<ShareCardRating> = emptyList()
) {
    val isEmpty: Boolean
        get() = playerName.isNullOrEmpty() && ratings.isEmpty()
}

enum class ShareCardGradient {
    ACCENT, MIDNIGHT, SUNSET, OCEAN, AURORA, MONO;

    fun colors(accentColor: Color): List<Color> = when (this) {
        ACCENT -> listOf(accentColor, lerp(accentColor, Color.Black, 0.75f))
        MIDNIGHT -> listOf(Color(0xFF291F5C), Color(0xFF05051A))
        SUNSET -> listOf(Color(0xFFFA7354), Color(0xFF731C6B))
        OCEAN -> listOf(Color(0xFF009ED1), Color(0xFF08245C))
        AURORA -> listOf(Color(0xFF33D999), Color(0xFF3D298C))
        MONO -> listOf(Color(0xFF474747), Color(0xFF0D0D0D))
    }
}

sealed interface ShareCardBackground {
    data class Gradient(val gradient: ShareCardGradient) : ShareCardBackground
    data class Icon(@param:DrawableRes val resId: Int) : ShareCardBackground
    data object Photo : ShareCardBackground
}
