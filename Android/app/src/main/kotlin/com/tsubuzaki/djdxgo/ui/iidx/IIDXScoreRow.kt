package com.tsubuzaki.djdxgo.ui.iidx

import android.text.format.DateUtils
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.tsubuzaki.djdxgo.data.iidx.IIDXClearType
import com.tsubuzaki.djdxgo.data.iidx.IIDXLevel
import com.tsubuzaki.djdxgo.data.iidx.IIDXLevelScore
import com.tsubuzaki.djdxgo.data.iidx.IIDXSongRecord
import androidx.compose.ui.res.stringResource
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.ui.theme.IIDXColors
import com.tsubuzaki.djdxgo.ui.theme.Palette
import java.util.Locale

@Composable
fun IIDXScoreRow(
    record: IIDXSongRecord,
    level: IIDXLevel,
    score: IIDXLevelScore,
    scoreRate: Float?,
    genreVisible: Boolean,
    artistVisible: Boolean,
    levelVisible: Boolean,
    djLevelVisible: Boolean,
    scoreRateVisible: Boolean,
    scoreVisible: Boolean,
    lastPlayDateVisible: Boolean,
    scoreDelta: Int? = null,
    onClick: () -> Unit
) {
    val darkTheme = isSystemInDarkTheme()
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .height(IntrinsicSize.Min),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        ClearLamp(clearType = score.clearType, darkTheme = darkTheme)
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            if (genreVisible && record.genre.isNotEmpty()) {
                Text(
                    text = record.genre,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
            Text(
                text = record.title,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Bold
            )
            if (artistVisible && record.artist.isNotEmpty()) {
                Text(
                    text = record.artist,
                    style = MaterialTheme.typography.bodySmall,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
            if (score.score != 0 &&
                (djLevelVisible || scoreRateVisible || scoreVisible || lastPlayDateVisible)
            ) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    if (djLevelVisible) {
                        Text(
                            text = score.djLevel,
                            style = MaterialTheme.typography.labelMedium.merge(
                                TextStyle(brush = IIDXColors.djLevelBrush(darkTheme))
                            ),
                            fontWeight = FontWeight.Black
                        )
                    }
                    if (scoreRateVisible && scoreRate != null) {
                        Text(
                            text = String.format(Locale.ROOT, "%.1f%%", scoreRate * 100f),
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.Black,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    if (scoreVisible) {
                        Text(
                            text = score.score.toString(),
                            style = MaterialTheme.typography.labelMedium.merge(
                                TextStyle(brush = IIDXColors.scoreBrush)
                            ),
                            fontWeight = FontWeight.ExtraBold
                        )
                        if (scoreDelta != null && scoreDelta > 0) {
                            Text(
                                text = stringResource(R.string.analytics_new_high_score_delta, scoreDelta),
                                style = MaterialTheme.typography.labelMedium,
                                fontWeight = FontWeight.ExtraBold,
                                color = Palette.orange
                            )
                        }
                    }
                    if (lastPlayDateVisible && record.lastPlayDate != 0L) {
                        Text(
                            text = DateUtils.getRelativeTimeSpanString(
                                record.lastPlayDate * 1000L
                            ).toString(),
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }
        if (levelVisible) {
            IIDXLevelBadge(
                level = level,
                difficulty = score.difficulty,
                darkTheme = darkTheme,
                modifier = Modifier.padding(vertical = 8.dp, horizontal = 8.dp)
            )
        }
    }
}

@Composable
private fun ClearLamp(clearType: String, darkTheme: Boolean) {
    val modifier = Modifier
        .width(10.dp)
        .fillMaxHeight()
    if (IIDXClearType.fromValue(clearType) == IIDXClearType.FULL_COMBO_CLEAR) {
        Box(modifier = modifier.background(IIDXColors.fullComboLampBrush))
    } else {
        Box(modifier = modifier.background(IIDXColors.lampColor(clearType, darkTheme)))
    }
}

@Composable
fun IIDXLevelBadge(
    level: IIDXLevel,
    difficulty: Int,
    darkTheme: Boolean,
    modifier: Modifier = Modifier
) {
    val levelColor = IIDXColors.levelColor(level)
    val color = if (darkTheme) lerp(Color.White, levelColor, 0.2f) else levelColor
    val glow = if (darkTheme) Shadow(color = levelColor, blurRadius = 12f) else null
    Surface(
        modifier = modifier.width(78.dp),
        shape = MaterialTheme.shapes.small,
        color = MaterialTheme.colorScheme.surfaceContainerHigh
    ) {
        Column(
            modifier = Modifier.padding(vertical = 6.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = difficulty.toString(),
                color = color,
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold,
                fontStyle = FontStyle.Italic,
                style = MaterialTheme.typography.titleLarge.copy(shadow = glow),
                textAlign = TextAlign.Center
            )
            Text(
                text = level.name,
                color = color,
                fontSize = 9.sp,
                fontWeight = FontWeight.SemiBold,
                style = MaterialTheme.typography.labelSmall.copy(shadow = glow),
                textAlign = TextAlign.Center,
                maxLines = 1
            )
        }
    }
}
