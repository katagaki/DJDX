package com.tsubuzaki.djdxgo.ui.analytics

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.tsubuzaki.djdxgo.R
import com.tsubuzaki.djdxgo.data.TrendPoint
import com.tsubuzaki.djdxgo.ui.common.HistoryLineChart
import com.tsubuzaki.djdxgo.ui.theme.Palette
import com.tsubuzaki.djdxgo.ui.theme.gameFont
import com.tsubuzaki.djdxgo.ui.theme.GameFontWidth
import java.text.DateFormat
import java.util.Date
import kotlin.math.abs

private fun trendBounds(points: List<TrendPoint>): Pair<Float, Float> {
    val minimum = points.minOfOrNull { it.value } ?: 0.0
    val maximum = points.maxOfOrNull { it.value } ?: 1.0
    val padding = maxOf((maximum - minimum) * 0.1, maximum * 0.01, 0.01)
    return (minimum - padding).coerceAtLeast(0.0).toFloat() to (maximum + padding).toFloat()
}

@Composable
internal fun ColumnScope.TrendCardContent(points: List<TrendPoint>, color: Color, format: (Double) -> String) {
    Text(
        text = points.lastOrNull()?.let { format(it.value) } ?: "-",
        style = MaterialTheme.typography.titleLarge.gameFont(GameFontWidth.EXPANDED),
        fontWeight = FontWeight.Black,
        color = if (points.isEmpty()) {
            MaterialTheme.colorScheme.onSurfaceVariant
        } else {
            MaterialTheme.colorScheme.onSurface
        },
        maxLines = 1
    )
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .weight(1f),
        contentAlignment = Alignment.Center
    ) {
        val (minimum, maximum) = trendBounds(points)
        HistoryLineChart(
            values = points.map { it.value.toFloat() },
            minValue = minimum,
            maxValue = maximum,
            color = color,
            modifier = Modifier
                .fillMaxSize()
                .padding(top = 4.dp)
        )
        if (points.isEmpty()) {
            Text(
                text = stringResource(R.string.analytics_no_data),
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.alpha(0.8f)
            )
        }
    }
}

@Composable
internal fun TrendDetail(
    points: List<TrendPoint>,
    color: Color,
    format: (Double) -> String,
    modifier: Modifier
) {
    if (points.isEmpty()) {
        Box(modifier = modifier, contentAlignment = Alignment.Center) {
            Text(
                text = stringResource(R.string.analytics_no_data),
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        return
    }
    val dateFormat = DateFormat.getDateInstance(DateFormat.MEDIUM)
    val (minimum, maximum) = trendBounds(points)
    LazyColumn(modifier = modifier, contentPadding = PaddingValues(16.dp)) {
        item {
            HistoryLineChart(
                values = points.map { it.value.toFloat() },
                minValue = minimum,
                maxValue = maximum,
                color = color,
                modifier = Modifier
                    .height(240.dp)
                    .padding(bottom = 16.dp)
            )
        }
        val reversed = points.withIndex().reversed()
        itemsIndexed(reversed) { position, (index, point) ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    text = dateFormat.format(Date(point.date * 1000L)),
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f)
                )
                val delta = if (index > 0) point.value - points[index - 1].value else 0.0
                if (delta != 0.0) {
                    Text(
                        text = (if (delta > 0) "+" else "-") + format(abs(delta)),
                        style = MaterialTheme.typography.labelMedium,
                        color = if (delta > 0) Palette.green else Palette.red
                    )
                }
                Text(
                    text = format(point.value),
                    style = MaterialTheme.typography.bodyMedium.gameFont(GameFontWidth.EXPANDED),
                    fontWeight = FontWeight.Black
                )
            }
            if (position < reversed.size - 1) {
                HorizontalDivider()
            }
        }
    }
}
