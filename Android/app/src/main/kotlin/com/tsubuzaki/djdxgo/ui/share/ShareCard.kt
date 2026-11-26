package com.tsubuzaki.djdxgo.ui.share

import androidx.annotation.DrawableRes
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.ui.common.RadarChart
import com.tsubuzaki.djdxgo.ui.theme.RadarColors
import com.tsubuzaki.djdxgo.ui.common.OutlinedText
import com.tsubuzaki.djdxgo.ui.common.SquashedHorizontally
import com.tsubuzaki.djdxgo.ui.theme.GameFontWidth
import com.tsubuzaki.djdxgo.ui.theme.GameFonts
import com.tsubuzaki.djdxgo.ui.theme.gameFont
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

val ShareCardWidth = 360.dp

@Composable
fun ShareCard(
    title: String,
    @DrawableRes iconRes: Int,
    profile: ShareCardProfile?,
    entries: List<ShareCardEntry>,
    totalCount: Int,
    playStyle: String?,
    background: ShareCardBackground,
    photo: ImageBitmap?,
    accentColor: Color,
    customColor: Color,
    modifier: Modifier = Modifier
) {
    Box(modifier = modifier.width(ShareCardWidth)) {
        ShareCardBackdrop(
            background = background,
            photo = photo,
            accentColor = accentColor,
            customColor = customColor,
            modifier = Modifier.matchParentSize()
        )
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            ShareCardHeader(title = title, iconRes = iconRes, profile = profile, playStyle = playStyle)
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(Color.Black.copy(alpha = 0.4f))
            ) {
                entries.forEachIndexed { index, entry ->
                    if (index > 0) {
                        Box(
                            modifier = Modifier
                                .padding(start = 18.dp)
                                .fillMaxWidth()
                                .height(0.5.dp)
                                .background(Color.White.copy(alpha = 0.12f))
                        )
                    }
                    ShareCardRow(entry)
                }
            }
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (totalCount > entries.size) {
                    Text(
                        text = stringResource(R.string.share_card_more, totalCount - entries.size),
                        style = footerStyle
                    )
                }
                Spacer(modifier = Modifier.weight(1f))
                Text(text = "DJDX", style = footerStyle.gameFont(GameFontWidth.EXTRA_EXPANDED))
            }
        }
    }
}

private val footerStyle = TextStyle(
    fontSize = 11.sp,
    fontWeight = FontWeight.ExtraBold,
    color = Color.White.copy(alpha = 0.7f)
)

@Composable
private fun ShareCardBackdrop(
    background: ShareCardBackground,
    photo: ImageBitmap?,
    accentColor: Color,
    customColor: Color,
    modifier: Modifier
) {
    when (background) {
        is ShareCardBackground.Gradient -> Box(
            modifier = modifier.background(
                Brush.linearGradient(background.gradient.colors(accentColor))
            )
        )
        ShareCardBackground.Custom -> Box(
            modifier = modifier.background(
                Brush.linearGradient(listOf(customColor, lerp(customColor, Color.Black, 0.75f)))
            )
        )
        ShareCardBackground.Photo -> Box(modifier = modifier.background(Color.Black)) {
            if (photo != null) {
                Image(
                    bitmap = photo,
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.matchParentSize()
                )
            }
            Box(modifier = Modifier.matchParentSize().background(Color.Black.copy(alpha = 0.35f)))
        }
    }
}

@Composable
private fun ShareCardHeader(
    title: String,
    @DrawableRes iconRes: Int,
    profile: ShareCardProfile?,
    playStyle: String?
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Image(
                painter = painterResource(iconRes),
                contentDescription = null,
                modifier = Modifier
                    .size(36.dp)
                    .clip(RoundedCornerShape(8.dp))
            )
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = TextStyle(fontSize = 15.sp, fontWeight = FontWeight.ExtraBold, color = Color.White)
                        .gameFont(GameFontWidth.EXPANDED),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    text = LocalDate.now().format(DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM)),
                    style = TextStyle(
                        fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White.copy(alpha = 0.7f)
                    )
                )
            }
            if (profile != null && !profile.isEmpty && !profile.hasVisuals) {
                ShareCardProfileText(profile, Alignment.End)
            }
            playStyle?.let {
                Text(
                    text = it,
                    style = TextStyle(fontSize = 13.sp, fontWeight = FontWeight.Black, color = Color.White)
                        .gameFont(GameFontWidth.EXPANDED),
                    modifier = Modifier
                        .clip(RoundedCornerShape(50))
                        .background(Color.White.copy(alpha = 0.2f))
                        .padding(horizontal = 10.dp, vertical = 5.dp)
                )
            }
        }
        if (profile != null && profile.hasVisuals) {
            ShareCardProfileBand(profile)
        }
    }
}

@Composable
private fun ShareCardProfileText(profile: ShareCardProfile, alignment: Alignment.Horizontal) {
    Column(horizontalAlignment = alignment, verticalArrangement = Arrangement.spacedBy(2.dp)) {
        profile.playerName?.takeIf { it.isNotEmpty() }?.let { name ->
            Text(
                text = name,
                style = TextStyle(fontSize = 15.sp, fontWeight = FontWeight.Bold, color = Color.White),
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
        }
        profile.ratings.forEach { rating ->
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                if (rating.label.isNotEmpty()) {
                    Text(
                        text = rating.label,
                        style = ratingStyle.copy(color = Color.White.copy(alpha = 0.7f)),
                        maxLines = 1,
                        modifier = Modifier.alignByBaseline()
                    )
                }
                Text(text = rating.value, style = ratingStyle, maxLines = 1, modifier = Modifier.alignByBaseline())
            }
        }
    }
}

@Composable
private fun ShareCardProfileBand(profile: ShareCardProfile) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        profile.avatar?.let {
            Image(
                bitmap = it,
                contentDescription = null,
                contentScale = ContentScale.Fit,
                modifier = Modifier.height(100.dp)
            )
        }
        Box(modifier = Modifier.weight(1f)) {
            ShareCardProfileText(profile, Alignment.Start)
        }
        profile.radar?.let { radar ->
            RadarChart(
                data = radar,
                color = RadarColors.playerColor(radar),
                labelSize = 8.dp,
                lineWidth = 1.5.dp,
                modifier = Modifier.size(width = 140.dp, height = 110.dp)
            )
        }
    }
}

private val ratingStyle = TextStyle(
    fontSize = 11.sp,
    fontWeight = FontWeight.ExtraBold,
    color = Color.White,
    fontFamily = GameFonts.family(GameFontWidth.CONDENSED)
)

@Composable
private fun ShareCardRow(entry: ShareCardEntry) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Min)
            .padding(end = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Box(
            modifier = Modifier
                .width(8.dp)
                .fillMaxHeight()
                .background(entry.lamp)
        )
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            val titleStrokeColor = entry.titleStrokeColor
            if (titleStrokeColor != null) {
                OutlinedText(
                    text = entry.title,
                    style = TextStyle(fontSize = 15.sp).gameFont(GameFontWidth.COMPRESSED),
                    fontWeight = FontWeight.Black,
                    fill = entry.titleBrush,
                    outline = titleStrokeColor,
                    outlineWidth = 0.35.dp,
                    squashed = true
                )
            } else {
                SquashedHorizontally(Modifier) {
                    Text(
                        text = entry.title,
                        style = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.Bold, brush = entry.titleBrush),
                        maxLines = 1,
                        softWrap = false,
                        overflow = TextOverflow.Visible
                    )
                }
            }
            entry.subtitle?.takeIf { it.isNotEmpty() }?.let { subtitle ->
                OutlinedText(
                    text = subtitle,
                    style = TextStyle(fontSize = 11.sp),
                    fontWeight = FontWeight.Black,
                    fill = Color.White,
                    outline = Color.Black.copy(alpha = 0.7f),
                    outlineWidth = 0.35.dp,
                    squashed = true
                )
            }
            if (entry.metrics.isNotEmpty()) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    entry.metrics.forEach { metric ->
                        Text(
                            text = metric.text,
                            style = TextStyle(
                                brush = metric.brush,
                                fontSize = 11.sp,
                                fontWeight = FontWeight.ExtraBold
                            ).gameFont(GameFontWidth.EXPANDED),
                            maxLines = 1
                        )
                    }
                }
            }
        }
        Column(
            modifier = Modifier
                .width(60.dp)
                .padding(vertical = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = entry.levelText,
                style = TextStyle(
                    fontSize = 17.sp,
                    fontWeight = FontWeight.Black,
                    fontStyle = FontStyle.Italic,
                    color = Color.White
                ),
                maxLines = 1
            )
            Text(
                text = entry.difficultyText,
                style = TextStyle(
                    fontSize = 9.sp,
                    fontWeight = FontWeight.ExtraBold,
                    color = entry.difficultyColor,
                    fontFamily = GameFonts.family(GameFontWidth.CONDENSED)
                ),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}
